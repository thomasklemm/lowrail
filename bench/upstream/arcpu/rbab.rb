# frozen_string_literal: true

# Interleaved ruby-bench runs across Rails worktrees (one process per run).
# The ruby-bench Gemfiles point at /home/user/workspace/rails-wt/bench, a symlink
# repointed before every run. Variant order rotates each round.
#   ruby rbab.rb --apps railsbench,lobsters,shipit --modes interp,yjit --rounds 4 \
#     --out DIR A=/path/base B=/path/base C2=/path/c2
#   ruby rbab.rb --summary DIR
require "optparse"
require "json"
require "fileutils"

RB = "/home/user/workspace/ruby-bench"
LINK = "/home/user/workspace/rails-wt/bench"
opts = { apps: %w[railsbench lobsters shipit], modes: %w[interp yjit], rounds: 4, warmup: nil, itrs: 15, harness: "harness" }
OptionParser.new do |o|
  o.on("--apps LIST") { opts[:apps] = _1.split(",") }
  o.on("--modes LIST") { opts[:modes] = _1.split(",") }
  o.on("--rounds N", Integer) { opts[:rounds] = _1 }
  o.on("--warmup N", Integer) { opts[:warmup] = _1 }
  o.on("--itrs N", Integer) { opts[:itrs] = _1 }
  o.on("--out DIR") { opts[:out] = _1 }
  o.on("--harness DIR") { opts[:harness] = _1 }
  o.on("--summary DIR") { opts[:summary] = _1 }
end.parse!

def summarize(dir)
  runs = (Dir[File.join(dir, "*.json")] - [File.join(dir, "variants.json")]).map { JSON.parse(File.read(_1)).merge("file" => _1) }
  med = ->(a) { s = a.sort; n = s.size; n.odd? ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2.0 }
  variants = JSON.parse(File.read(File.join(dir, "variants.json")))
  base = variants.first
  runs.group_by { [_1["app"], _1["mode"]] }.sort.each do |(app, mode), rs|
    by = rs.group_by { _1["variant"] }
    # per process: mean of timed iterations (ms); per variant: median over processes
    %w[bench cpu_bench].each do |key|
      next unless rs.first[key]
      per = by.transform_values { |v| v.map { |r| 1000.0 * r[key].sum / r[key].size } }
      b = med.(per.fetch(base))
      cells = variants.filter_map do |name|
        next unless per[name]
        m = med.(per[name])
        format("%s %.1f ms (%.4f; %s)", name, m, m / b, per[name].map { format("%.0f", _1) }.join("/"))
      end
      puts "#{app} #{mode} #{key == 'bench' ? 'wall' : 'cpu'}: #{cells.join(' | ')}"
    end
  end
end

if opts[:summary]
  summarize(opts[:summary])
  exit
end

variants = ARGV.map { _1.split("=", 2) }
out = opts.fetch(:out)
FileUtils.mkdir_p(out)
File.write(File.join(out, "variants.json"), JSON.dump(variants.map(&:first)))
opts[:rounds].times do |round|
  opts[:apps].each do |app|
    opts[:modes].each do |mode|
      variants.rotate(round % variants.size).each do |name, dir|
        File.unlink(LINK) if File.symlink?(LINK)
        File.symlink(dir, LINK)
        json = File.join(out, "#{app}-#{mode}-#{name}-r#{round}.json")
        warmup = opts[:warmup] || (mode == "yjit" ? 10 : 3)
        env = { "WARMUP_ITRS" => warmup.to_s, "MIN_BENCH_ITRS" => opts[:itrs].to_s, "MIN_BENCH_TIME" => "0",
                "RESULT_JSON_PATH" => json }
        cmd = ["ruby", *("--yjit" if mode == "yjit"), "-I#{opts[:harness]}", "benchmarks/#{app}/benchmark.rb"]
        ok = system(env, *cmd, chdir: RB, out: File.join(out, "#{app}-#{mode}-#{name}-r#{round}.log"), err: [:child, :out])
        abort "failed: #{app} #{mode} #{name} r#{round}" unless ok
        data = JSON.parse(File.read(json))
        File.write(json, JSON.dump(data.slice("bench", "warmup", "cpu_bench", "cpu_warmup", "RUBY_DESCRIPTION").merge(
          "app" => app, "mode" => mode, "variant" => name, "round" => round, "dir" => dir,
          "rails_head" => `git -C #{dir} rev-parse HEAD`.strip,
        )))
        $stderr.puts "#{Time.now.strftime('%H:%M:%S')} r#{round} #{app} #{mode} #{name}: #{(1000.0 * data['bench'].sum / data['bench'].size).round(1)} ms"
      end
    end
  end
end
summarize(out)
