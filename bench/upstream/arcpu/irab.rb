# frozen_string_literal: true

# Callgrind instruction counts for ruby-bench apps across Rails worktrees.
# Each variant gets Gemfile.v-NAME(.lock) next to the app's Gemfile with the
# Rails path rewritten, so variants need no symlink; apps run in parallel,
# variants of one app in sequence (railsbench reseeds its database at start).
#   ruby irab.rb --out DIR [--apps ...] [--yjit|--zjit] [--itrs 1] [--warmup 1] NAME=DIR...
# --zjit needs a ZJIT-enabled ruby first in PATH (e.g. a Ruby master build).
#   ruby irab.rb --summary DIR
require "optparse"
require "json"
require "fileutils"

RB = "/home/user/workspace/ruby-bench"
LINK = "/home/user/workspace/rails-wt/bench"
VG = "/tmp/vg/bin/valgrind"
opts = { apps: %w[railsbench lobsters shipit], yjit: false, itrs: 1, warmup: nil }
OptionParser.new do |o|
  o.on("--apps LIST") { opts[:apps] = _1.split(",") }
  o.on("--yjit") { opts[:yjit] = true }
  o.on("--zjit") { opts[:zjit] = true }
  o.on("--itrs N", Integer) { opts[:itrs] = _1 }
  o.on("--warmup N", Integer) { opts[:warmup] = _1 }
  o.on("--out DIR") { opts[:out] = _1 }
  o.on("--summary DIR") { opts[:summary] = _1 }
end.parse!

def summarize(dir)
  rows = (Dir[File.join(dir, "*.json")] - [File.join(dir, "variants.json")]).map { JSON.parse(File.read(_1)) }
  variants = JSON.parse(File.read(File.join(dir, "variants.json")))
  rows.group_by { _1["app"] }.sort.each do |app, rs|
    by = rs.to_h { [_1["variant"], _1["ir"]] }
    base = by[variants.first] or next
    cells = variants.filter_map do |v|
      next unless by[v]
      format("%s %.4f G (%+.3f%%)", v, by[v] / 1e9, 100.0 * (by[v] - base) / base)
    end
    puts "#{app}#{rs.first['yjit'] ? ' yjit' : ''}#{rs.first['zjit'] ? ' zjit' : ''}: #{cells.join(' | ')}"
  end
end

if opts[:summary]
  summarize(opts[:summary])
  exit
end

out = File.expand_path(opts.fetch(:out))
FileUtils.mkdir_p(out)
variants = ARGV.map { _1.split("=", 2) }
File.write(File.join(out, "variants.json"), JSON.dump(variants.map(&:first)))

# Per-variant Gemfiles.
opts[:apps].each do |app|
  dir = File.join(RB, "benchmarks", app)
  variants.each do |name, path|
    %w[Gemfile Gemfile.lock].each do |f|
      dst = f == "Gemfile" ? "Gemfile.v-#{name}" : "Gemfile.v-#{name}.lock"
      File.write(File.join(dir, dst), File.read(File.join(dir, f)).gsub(LINK, path))
    end
  end
end

threads = opts[:apps].map do |app|
  Thread.new do
    variants.each do |name, path|
      base = File.join(out, "#{app}-#{name}")
      env = { "BUNDLE_GEMFILE" => File.join(RB, "benchmarks", app, "Gemfile.v-#{name}"),
              "WARMUP_ITRS" => (opts[:warmup] || (opts[:yjit] || opts[:zjit] ? 10 : 1)).to_s, "IR_ITRS" => opts[:itrs].to_s }
      cmd = [VG, "--tool=callgrind", "--collect-atstart=no", "--toggle-collect=rb_ary_cycle", "-v",
             *("--smc-check=all" if opts[:yjit] || opts[:zjit]), "--callgrind-out-file=#{base}.callgrind",
             "ruby", *("--yjit" if opts[:yjit]), *("--zjit" if opts[:zjit]), "-Iharness-ir", "benchmarks/#{app}/benchmark.rb"]
      ok = system(env, *cmd, chdir: RB, out: "#{base}.log", err: [:child, :out])
      log = File.read("#{base}.log")
      ir = log[/Collected : (\d+)/, 1]
      warn "#{app} #{name}: brk/overflow warning" if log.match?(/brk segment overflow|cannot grow brk/i)
      abort "failed #{app} #{name}" unless ok && ir
      loaded = log[/RUBY_LOADED_RAILS=(\S+)/, 1]
      File.write("#{base}.json", JSON.dump("app" => app, "variant" => name, "dir" => path, "ir" => Integer(ir),
        "yjit" => opts[:yjit], "zjit" => opts[:zjit], "itrs" => opts[:itrs], "rails_head" => `git -C #{path} rev-parse HEAD`.strip))
      $stderr.puts "#{Time.now.strftime('%H:%M:%S')} #{app} #{name}: #{ir}"
    end
  end
end
threads.each(&:join)
summarize(out)
