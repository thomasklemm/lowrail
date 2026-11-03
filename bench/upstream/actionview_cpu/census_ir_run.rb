# frozen_string_literal: true

# Runs census_ir.rb under Valgrind (cachegrind, no cache simulation) for Rails
# variants in the census app copies, and summarizes instructions per round of
# GET page workloads. A variant is NAME=SHA, with its census bundle already
# installed (script/census run --rails ... creates Gemfile.census-SHA12).
#   ruby census_ir_run.rb run --out DIR --valgrind PATH --apps blog,campfire \
#     [--modes interpreter,yjit] [--short 2 --long 8] main-a=SHA c1=SHA main-b=SHA
#   ruby census_ir_run.rb summary --out DIR [--base main-a] [--markdown]
# Apps run in parallel; within an app, runs go one at a time in the given
# variant order (the workload setup writes a little to the app's database, so
# runs of one copy must not overlap), each pair after a native priming run.
# Two variants with the same SHA are the A/A pair.
require "json"
require "optparse"
require "open3"
require "fileutils"

ROOT = File.expand_path("../../..", __dir__)
cmd = ARGV.shift
opts = { modes: %w[interpreter yjit], short: 2, long: 8, base: "main-a", corpus: "census" }
OptionParser.new do |o|
  o.on("--out DIR") { opts[:out] = File.expand_path(_1) }
  o.on("--valgrind PATH") { opts[:valgrind] = _1 }
  o.on("--apps LIST") { opts[:apps] = _1.split(",") }
  o.on("--modes LIST") { opts[:modes] = _1.split(",") }
  o.on("--short N", Integer) { opts[:short] = _1 }
  o.on("--long N", Integer) { opts[:long] = _1 }
  o.on("--base NAME") { opts[:base] = _1 }
  o.on("--markdown") { opts[:markdown] = true }
end.parse!
out = opts.fetch(:out)

case cmd
when "run"
  FileUtils.mkdir_p(out)
  variants = ARGV.map { _1.split("=", 2) }
  ruby_bin = File.dirname(Gem.ruby)
  threads = opts.fetch(:apps).map do |app|
    Thread.new do
      dir = File.join(ROOT, ".corpus", "#{opts[:corpus]}-#{app}")
      opts[:modes].each do |mode|
        variants.each do |variant, sha|
          primed = false
          [opts[:short], opts[:long]].each do |rounds|
            name = "#{app}-#{mode}-#{variant}-#{rounds}"
            next if File.exist?(File.join(out, "#{name}.ir"))
            env = { "PATH" => "#{ruby_bin}:#{ENV.fetch("PATH")}", "RUBYOPT" => nil, "GEM_HOME" => nil, "GEM_PATH" => nil,
                    "BUNDLE_GEMFILE" => File.join(dir, "Gemfile.census-#{sha[0, 12]}"), "BUNDLE_FROZEN" => "true",
                    "RAILS_ENV" => "production", "RACK_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1",
                    "RAILS_LOG_LEVEL" => "fatal", "SKIP_TELEMETRY" => "1", "APP_VERSION" => "census",
                    "APP_HOST" => "localhost", "RUBY_YJIT_ENABLE" => "0", "CENSUS_RAILS_SHA" => sha,
                    "CENSUS_MODE" => mode, "AVCPU_ROUNDS" => rounds.to_s }
            ruby_cmd = [File.join(ruby_bin, "ruby"), "-rbundler/setup", *("--yjit" if mode == "yjit"),
                        File.join(__dir__, "census_ir.rb"), app]
            # The apps keep fragment caches in Redis or Solid Cache across
            # processes. One native run first leaves them warm, so both
            # measured runs start from the same cache state.
            unless primed
              log, status = Open3.capture2e(env.merge("AVCPU_ROUNDS" => "1", "AVCPU_WARMUP" => "3"), *ruby_cmd, chdir: dir)
              abort "#{name} priming failed:\n#{log[-2000..]}" unless status.success?
              primed = true
            end
            vg = [opts.fetch(:valgrind), "--tool=cachegrind", "--cache-sim=no", "--branch-sim=no",
                  "--cachegrind-out-file=/dev/null"]
            vg << "--smc-check=all-non-file" if mode == "yjit"
            cmdline = [*vg, *ruby_cmd]
            log, status = Open3.capture2e(env, *cmdline, chdir: dir)
            File.write(File.join(out, "#{name}.log"), log)
            ir = log[/I\s+refs:\s+([\d,]+)/, 1]
            abort "#{name} failed (#{status}); see #{name}.log" unless status.success? && ir
            File.write(File.join(out, "#{name}.ir"), ir.delete(",") + "\n")
            warn "#{name}: #{ir}"
          end
        end
      end
    end
  end
  threads.each(&:join)
when "summary"
  ir = Dir[File.join(out, "*.ir")].to_h do |f|
    File.basename(f, ".ir") =~ /\A(.+)-(interpreter|yjit)-(.+)-(\d+)\z/
    [[$1, $2, $3, $4.to_i], Integer(File.read(f))]
  end
  rounds = ir.keys.map(&:last).uniq.sort
  short, long = rounds.first, rounds.last
  per = ir.keys.map { _1[0, 3] }.uniq.filter_map do |k|
    l, s = ir[[*k, long]], ir[[*k, short]]
    [k, (l - s) / (long - short).to_f] if l && s
  end.to_h
  rows = per.filter_map do |(app, mode, variant), v|
    base = per[[app, mode, opts[:base]]]
    next unless base && variant != opts[:base]
    { app: app, mode: mode, variant: variant, base: base, ir: v, delta: (v / base - 1) * 100 }
  end.sort_by { _1.values_at(:mode, :variant, :app) }
  if opts[:markdown]
    puts "| App | Mode | Variant | #{opts[:base]} Ir/round | Variant Ir/round | Δ |"
    puts "| --- | --- | --- | ---: | ---: | ---: |"
    rows.each { |r| puts format("| %s | %s | %s | %.4g | %.4g | %+.2f%% |", *r.values_at(:app, :mode, :variant, :base, :ir, :delta)) }
  else
    rows.each { |r| puts format("%-10s %-11s %-8s base %.5g  Ir %.5g  %+.3f%%", *r.values_at(:app, :mode, :variant, :base, :ir, :delta)) }
  end
else
  abort "usage: census_ir_run.rb run|summary ..."
end
