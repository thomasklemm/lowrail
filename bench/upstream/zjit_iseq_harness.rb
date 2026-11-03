require_relative File.join(ENV.fetch("RUBY_BENCH", "../lib"), "harness")
# ruby-bench harness for --zjit-stats-iseq (docs/upstream/zjit-iseq-leads.md). From a ruby-bench checkout:
#   ZJIT_STATS_JSON=out.json ruby --zjit --zjit-stats-iseq -r ./harness/zjitiseq.rb benchmarks/B/benchmark.rb
# Warms up, resets ZJIT stats, runs the measured iterations and writes every non-zero counter as JSON.
WARMUP_ITRS = Integer(ENV.fetch('WARMUP_ITRS', 15))
MIN_BENCH_ITRS = Integer(ENV.fetch('MIN_BENCH_ITRS', 10))

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  RubyVM::ZJIT.reset_stats!
  MIN_BENCH_ITRS.times { block.call }
  require "json" # after Bundler.setup, so the Gemfile's json is activated
  stats = RubyVM::ZJIT.stats.select { |_, v| v.is_a?(Integer) && v != 0 }
  File.write(ENV.fetch("ZJIT_STATS_JSON"), JSON.generate(app: File.basename(Dir.pwd), ruby: RUBY_DESCRIPTION, ops: MIN_BENCH_ITRS, stats:))
end
