require_relative "../lib/harness"

# Local harness: objects allocated per iteration after warmup.
# Prints "ALLOCS <median> <min> <max>" and writes nothing else.
WARMUP_ITRS = Integer(ENV.fetch('WARMUP_ITRS', 15))
MIN_BENCH_ITRS = Integer(ENV.fetch('MIN_BENCH_ITRS', 10))

puts RUBY_DESCRIPTION

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  counts = MIN_BENCH_ITRS.times.map do
    before = GC.stat(:total_allocated_objects)
    block.call
    GC.stat(:total_allocated_objects) - before
  end.sort
  puts "ALLOCS #{counts[counts.size / 2]} #{counts.first} #{counts.last}"
end
