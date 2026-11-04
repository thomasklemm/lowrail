require_relative "../lib/harness"

# Allocation harness for Lowrail's docs/upstream/merged-sum.md: fixed warmup,
# then BENCH_ITRS iterations, each recording allocated objects and GC runs
# (read outside the iteration). Writes one JSON to SUM_OUT.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 5))
BENCH_ITRS = Integer(ENV.fetch("BENCH_ITRS", 10))

def run_benchmark(_hint, **)
  WARMUP_ITRS.times { yield }
  rows = BENCH_ITRS.times.map do
    g0 = GC.stat
    yield
    g1 = GC.stat
    { "objects" => g1[:total_allocated_objects] - g0[:total_allocated_objects],
      "gc" => g1[:count] - g0[:count], "major" => g1[:major_gc_count] - g0[:major_gc_count] }
  end
  require "json" # after Bundler.setup, so the app's pinned json is the one loaded
  yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
  File.write(ENV.fetch("SUM_OUT"), JSON.pretty_generate("ruby" => RUBY_DESCRIPTION, "yjit" => yjit, "iterations" => rows))
end
