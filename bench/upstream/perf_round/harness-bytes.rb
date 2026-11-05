# ruby-bench harness (copy to harness/bytes.rb): WARMUP_ITRS iterations, then BENCH_ITRS iterations; prints
# objects and slot bytes allocated per iteration (sum over heaps of slot_size x new objects) as JSON to BY_OUT.
require_relative "../lib/harness"

WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 2))
BENCH_ITRS = Integer(ENV.fetch("BENCH_ITRS", 10))

def run_benchmark(_hint, **)
  WARMUP_ITRS.times { yield }
  heaps = GC.stat_heap.keys
  snap = -> { heaps.to_h { [_1, GC.stat_heap(_1, :total_allocated_objects)] } }
  per = []
  BENCH_ITRS.times do
    a = snap.call
    yield
    b = snap.call
    per << [heaps.sum { b[_1] - a[_1] }, heaps.sum { (b[_1] - a[_1]) * GC.stat_heap(_1, :slot_size) }]
  end
  require "json"
  File.write(ENV.fetch("BY_OUT"), JSON.generate(ruby: RUBY_DESCRIPTION, objects: per.sum(&:first) / per.size.to_f, bytes: per.sum(&:last) / per.size.to_f, per: per) + "\n")
end
