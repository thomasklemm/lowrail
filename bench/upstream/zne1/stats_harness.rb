require_relative "../lib/harness"

# ruby-bench harness for docs/upstream/zjit-not-equal.md: WARMUP_ITRS, reset ZJIT stats, MIN_BENCH_ITRS,
# then every non-zero counter per iteration as JSON to ZNE1_JSON.
#   cp stats_harness.rb RUBY_BENCH/harness/zne1.rb
#   HARNESS=zne1 ZNE1_JSON=out.json ruby --zjit --zjit-stats-quiet benchmarks/B/benchmark.rb
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 100))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 10))

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  RubyVM::ZJIT.reset_stats!
  MIN_BENCH_ITRS.times { block.call }
  stats = RubyVM::ZJIT.stats.select { |_, v| v.is_a?(Integer) && v != 0 }
  require "json" # after Bundler.setup: the benchmark may pin another json
  File.write(ENV.fetch("ZNE1_JSON"), JSON.pretty_generate(ruby: RUBY_DESCRIPTION, itrs: MIN_BENCH_ITRS, stats:) + "\n")
end
