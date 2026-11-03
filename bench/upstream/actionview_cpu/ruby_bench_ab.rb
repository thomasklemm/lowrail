# frozen_string_literal: true

# Interleaved ruby-bench runs of Rails variants with an A/A control.
#   ruby ruby_bench_ab.rb run --out DIR --rounds 5 --benches erubi-rails,railsbench \
#     --modes interpreter,yjit --ruby PATH VARIANT...
#   ruby ruby_bench_ab.rb summary --out DIR --base main-a [--markdown]
# Each VARIANT is NAME, with a bundle at benchmarks/BENCH/Gemfile.NAME (see
# docs/upstream/actionview-cpu.md). Every round runs every variant once per
# bench and mode, in an order rotated by round, with ruby-bench's default
# harness (WARMUP_ITRS, MIN_BENCH_ITRS, MIN_BENCH_TIME=0). A run's value is the
# median of its timed iterations; a variant's delta is the median over rounds
# of (variant / base - 1), paired by round. Two copies of main (main-a, main-b)
# give the A/A row.
require "json"
require "optparse"
require "fileutils"

RUBY_BENCH = ENV.fetch("RUBY_BENCH_DIR", File.expand_path("~/src/ruby-bench"))
cmd = ARGV.shift
opts = { rounds: 5, benches: %w[erubi-rails railsbench], modes: %w[interpreter yjit], warmup: 10, itrs: 20,
         base: "main-a", ruby: "ruby", tag: "r40" }
OptionParser.new do |o|
  o.on("--out DIR") { opts[:out] = _1 }
  o.on("--rounds N", Integer) { opts[:rounds] = _1 }
  o.on("--benches LIST") { opts[:benches] = _1.split(",") }
  o.on("--modes LIST") { opts[:modes] = _1.split(",") }
  o.on("--ruby PATH") { opts[:ruby] = _1 }
  o.on("--tag T") { opts[:tag] = _1 }
  o.on("--warmup N", Integer) { opts[:warmup] = _1 }
  o.on("--itrs N", Integer) { opts[:itrs] = _1 }
  o.on("--base NAME") { opts[:base] = _1 }
  o.on("--markdown") { opts[:markdown] = true }
end.parse!
out = File.expand_path(opts.fetch(:out))

def median(a) = (s = a.sort; s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0)

case cmd
when "run"
  variants = ARGV
  abort "variants required" if variants.empty?
  FileUtils.mkdir_p(out)
  opts[:rounds].times do |round|
    opts[:benches].each do |bench|
      opts[:modes].each do |mode|
        variants.rotate(round).each do |v|
          path = File.join(out, "#{opts[:tag]}-#{bench}-#{mode}-#{v}-#{round}.json")
          next if File.exist?(path)
          env = { "BUNDLE_GEMFILE" => File.join(RUBY_BENCH, "benchmarks", bench, "Gemfile.#{v}"),
                  "RESULT_JSON_PATH" => path, "WARMUP_ITRS" => opts[:warmup].to_s,
                  "MIN_BENCH_ITRS" => opts[:itrs].to_s, "MIN_BENCH_TIME" => "0", "HARNESS" => "default" }
          flags = mode == "yjit" ? ["--yjit"] : []
          ok = system(env, opts[:ruby], *flags, File.join("benchmarks", bench, "benchmark.rb"), chdir: RUBY_BENCH,
            out: File::NULL, err: File.join(out, "last.err"))
          abort "#{bench} #{mode} #{v} failed; see #{out}/last.err" unless ok
          r = JSON.parse(File.read(path))
          warn format("round %d %-12s %-11s %-10s %8.2f ms", round, bench, mode, v, 1000 * median(r["bench"]))
        end
      end
    end
  end
when "summary"
  runs = Dir[File.join(out, "*.json")].filter_map do |f|
    next unless File.basename(f) =~ /\A([^-]+)-(.+)-(interpreter|yjit)-(.+)-(\d+)\.json\z/
    tag, bench, mode, variant, round = $1, $2, $3, $4, $5.to_i
    { tag: tag, bench: bench, mode: mode, variant: variant, round: round, ms: 1000 * median(JSON.parse(File.read(f))["bench"]) }
  end
  rows = []
  runs.group_by { [_1[:tag], _1[:bench], _1[:mode]] }.sort.each do |(tag, bench, mode), group|
    by = group.group_by { _1[:variant] }
    base = by.fetch(opts[:base]) { next }.to_h { [_1[:round], _1[:ms]] }
    by.keys.sort.each do |v|
      next if v == opts[:base]
      pairs = by[v].filter_map { |r| base[r[:round]] && (r[:ms] / base[r[:round]] - 1) * 100 }
      rows << { tag: tag, bench: bench, mode: mode, variant: v, n: pairs.size, base_ms: median(base.values),
                ms: median(by[v].map { _1[:ms] }), delta: median(pairs), min: pairs.min, max: pairs.max }
    end
  end
  if opts[:markdown]
    puts "| Ruby | Benchmark | Mode | Variant | Rounds | #{opts[:base]} ms | Variant ms | Δ median | Δ range |"
    puts "| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- |"
    rows.each do |r|
      puts format("| %s | %s | %s | %s | %d | %.1f | %.1f | %+.2f%% | %+.2f … %+.2f%% |", r[:tag], r[:bench], r[:mode], r[:variant],
        r[:n], r[:base_ms], r[:ms], r[:delta], r[:min], r[:max])
    end
  else
    rows.each do |r|
      puts format("%-4s %-12s %-11s %-14s n=%d base %8.1f ms  %8.1f ms  delta %+6.2f%%  [%+.2f, %+.2f]", r[:tag], r[:bench],
        r[:mode], r[:variant], r[:n], r[:base_ms], r[:ms], r[:delta], r[:min], r[:max])
    end
  end
else
  abort "usage: ruby_bench_ab.rb run|summary ..."
end
