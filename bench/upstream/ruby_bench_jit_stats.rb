require_relative "../lib/harness"

# Local ruby-bench harness: JIT counters per iteration after warmup.
# Run with --zjit --zjit-stats-quiet or --yjit --yjit-stats=quiet; writes every
# numeric counter divided by the iteration count to $JIT_STATS_JSON.
# Add --zjit-trace-exits-sample-rate=N / --zjit-trace-fallbacks-sample-rate=N for sites.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 10))

puts RUBY_DESCRIPTION

def run_benchmark(_num_itrs_hint, **, &block)
  jit = RubyVM::ZJIT.enabled? ? RubyVM::ZJIT : RubyVM::YJIT
  WARMUP_ITRS.times { block.call }
  jit.reset_stats!
  MIN_BENCH_ITRS.times { block.call }
  require "json" # after Bundler.setup: the benchmark may pin another json
  stats = jit == RubyVM::YJIT ? jit.runtime_stats : jit.stats
  per_itr = stats.filter_map { |k, v| [k, v.fdiv(MIN_BENCH_ITRS)] if v.is_a?(Numeric) && v != 0 }.to_h
  File.write(ENV.fetch("JIT_STATS_JSON"), JSON.pretty_generate(ruby: RUBY_DESCRIPTION, jit: jit.name,
    warmup: WARMUP_ITRS, itrs: MIN_BENCH_ITRS, per_itr: per_itr) + "\n")
end
