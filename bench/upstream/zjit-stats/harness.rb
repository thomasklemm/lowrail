require_relative "../lib/harness"

# ruby-bench harness for docs/upstream/zjit-stats-2026-11-18.md (copy to harness/zstats.rb).
# Run with --zjit --zjit-stats-quiet. Writes $JIT_STATS_JSON with every non-zero numeric
# ZJIT counter: "boot_warmup" is cumulative from boot through the warmup iterations (where
# compiles and compile failures happen), "per_itr" is the measured window divided by its
# iteration count.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 10))

puts RUBY_DESCRIPTION

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  warm = RubyVM::ZJIT.stats.select { |_, v| v.is_a?(Numeric) && v != 0 }
  RubyVM::ZJIT.reset_stats!
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  MIN_BENCH_ITRS.times { block.call }
  ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000.0 / MIN_BENCH_ITRS
  stats = RubyVM::ZJIT.stats
  require "json" # after Bundler.setup: the benchmark may pin another json
  per_itr = stats.filter_map { |k, v| [k, v.fdiv(MIN_BENCH_ITRS)] if v.is_a?(Numeric) && v != 0 }.to_h
  File.write(ENV.fetch("JIT_STATS_JSON"), JSON.pretty_generate(ruby: RUBY_DESCRIPTION, warmup: WARMUP_ITRS,
    itrs: MIN_BENCH_ITRS, ms_per_itr: ms.round(1), boot_warmup: warm, per_itr: per_itr) + "\n")
end
