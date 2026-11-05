# frozen_string_literal: true

# Instruction counts per ruby-bench iteration, under Valgrind (cachegrind,
# no cache simulation), for Rails variants. Counts do not depend on machine
# load, so runs go in parallel; the variation between two copies of main
# (main-a, main-b) is the A/A floor.
#   ruby ruby_bench_ir.rb run --out DIR --valgrind PATH/bin/valgrind --ruby PATH/bin/ruby \
#     [--benches erubi-rails,railsbench] [--modes interpreter,yjit] [--jobs 6] VARIANT...
#   ruby ruby_bench_ir.rb summary --out DIR [--base main-a] [--markdown]
# Each variant runs ruby-bench's default harness twice: WARMUP_ITRS (--warmup, default 2) with
# MIN_BENCH_ITRS=1, and with MIN_BENCH_ITRS=--long (default 4). Ir per iteration is
# the difference over the extra iterations, so boot and warmup cancel. YJIT runs
# use --smc-check=all-non-file (YJIT writes code at run time).
require "json"
require "optparse"
require "fileutils"
require "open3"

RUBY_BENCH = ENV.fetch("RUBY_BENCH_DIR", File.expand_path("~/src/ruby-bench"))
SHORT = 1
cmd = ARGV.shift
opts = { benches: %w[erubi-rails railsbench], modes: %w[interpreter yjit], jobs: 6, base: "main-a", tag: "r40", warmup: 2, long: 4 }
OptionParser.new do |o|
  o.on("--out DIR") { opts[:out] = File.expand_path(_1) }
  o.on("--valgrind PATH") { opts[:valgrind] = _1 }
  o.on("--ruby PATH") { opts[:ruby] = _1 }
  o.on("--benches LIST") { opts[:benches] = _1.split(",") }
  o.on("--modes LIST") { opts[:modes] = _1.split(",") }
  o.on("--jobs N", Integer) { opts[:jobs] = _1 }
  o.on("--base NAME") { opts[:base] = _1 }
  o.on("--tag T") { opts[:tag] = _1 }
  o.on("--warmup N", Integer) { opts[:warmup] = _1 }
  o.on("--long N", Integer) { opts[:long] = _1 }
  o.on("--markdown") { opts[:markdown] = true }
end.parse!
out = opts.fetch(:out)

case cmd
when "run"
  FileUtils.mkdir_p(out)
  queue = Queue.new
  opts[:benches].product(opts[:modes], ARGV, [SHORT, opts[:long]]).each { queue << _1 }
  queue.close
  workers = opts[:jobs].times.map do
    Thread.new do
      while (bench, mode, variant, itrs = queue.pop)
        name = "#{opts[:tag]}-#{bench}-#{mode}-#{variant}-#{itrs}"
        result = File.join(out, "#{name}.ir")
        next if File.exist?(result)
        env = { "BUNDLE_GEMFILE" => File.join(RUBY_BENCH, "benchmarks", bench, "Gemfile.#{variant}"),
                "RESULT_JSON_PATH" => File.join(out, "#{name}.json"), "WARMUP_ITRS" => opts[:warmup].to_s,
                "MIN_BENCH_ITRS" => itrs.to_s, "MIN_BENCH_TIME" => "0", "HARNESS" => "default" }
        # railsbench re-seeds its SQLite database in every process; parallel
        # runs each get their own (DATABASE_URL merges into config/database.yml).
        env["DATABASE_URL"] = "sqlite3:#{File.join(out, "#{name}.sqlite3")}" if bench == "railsbench"
        vg = [opts.fetch(:valgrind), "--tool=cachegrind", "--cache-sim=no", "--branch-sim=no",
              "--cachegrind-out-file=/dev/null"]
        if mode == "yjit"
          vg << "--smc-check=all-non-file"
          env["RUBYOPT"] = "-r#{File.expand_path("jit_counts.rb", __dir__)}"
          env["JIT_COUNTS_PATH"] = File.join(out, "#{name}.jit")
        end
        cmdline = [*vg, opts.fetch(:ruby), *("--yjit" if mode == "yjit"), File.join("benchmarks", bench, "benchmark.rb")]
        log, status = Open3.capture2e(env, *cmdline, chdir: RUBY_BENCH)
        File.write(File.join(out, "#{name}.log"), log)
        ir = log[/I\s+refs:\s+([\d,]+)/, 1]
        abort "#{name} failed (#{status}); see #{name}.log" unless status.success? && ir
        File.write(result, ir.delete(",") + "\n")
        warn "#{name}: #{ir}"
      end
    end
  end
  workers.each(&:join)
when "summary"
  ir = Dir[File.join(out, "*.ir")].to_h do |f|
    File.basename(f, ".ir") =~ /\A([^-]+)-(.+)-(interpreter|yjit)-(.+)-(\d+)\z/
    [[$1, $2, $3, $4, $5.to_i], Integer(File.read(f))]
  end
  per = ir.keys.map { _1[0, 4] }.uniq.filter_map do |k|
    long_itrs = ir.keys.select { _1[0, 4] == k }.map(&:last).max
    long, short = ir[[*k, long_itrs]], ir[[*k, SHORT]]
    [k, (long - short) / (long_itrs - SHORT).to_f] if long && short && long_itrs > SHORT
  end.to_h
  # YJIT runs: flat when the long run's counters (jit_counts.rb) did not change
  # over the iterations the difference measures.
  flat = per.keys.to_h do |k|
    long_itrs = ir.keys.select { _1[0, 4] == k }.map(&:last).max
    counts = File.read(File.join(out, "#{k.join("-")}-#{long_itrs}.jit")) rescue nil
    before, after = counts && counts[/before: (\{.*?\})/, 1], counts && counts[/after: (\{.*?\})/, 1]
    [k, k[2] != "yjit" || (before && before == after)]
  end
  rows = per.filter_map do |(tag, bench, mode, variant), v|
    base = per[[tag, bench, mode, opts[:base]]]
    next unless base && variant != opts[:base]
    jit = mode != "yjit" ? "" : flat[[tag, bench, mode, variant]] && flat[[tag, bench, mode, opts[:base]]] ? "flat" : "NOT-FLAT"
    { tag: tag, bench: bench, mode: mode, variant: variant, base: base, ir: v, delta: (v / base - 1) * 100, jit: jit }
  end.sort_by { _1.values_at(:tag, :bench, :mode, :variant) }
  if opts[:markdown]
    puts "| Ruby | Benchmark | Mode | Variant | #{opts[:base]} Ir/iteration | Variant Ir/iteration | Δ | YJIT |"
    puts "| --- | --- | --- | --- | ---: | ---: | ---: | --- |"
    rows.each { |r| puts format("| %s | %s | %s | %s | %.4g | %.4g | %+.2f%% | %s |", *r.values_at(:tag, :bench, :mode, :variant, :base, :ir, :delta, :jit)) }
  else
    rows.each { |r| puts format("%-4s %-12s %-11s %-10s base %.5g  Ir %.5g  %+.3f%%  %s", *r.values_at(:tag, :bench, :mode, :variant, :base, :ir, :delta, :jit)) }
  end
else
  abort "usage: ruby_bench_ir.rb run|summary ..."
end
