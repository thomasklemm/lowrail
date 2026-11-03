require_relative "../lib/harness"

# Local ruby-bench harness: Callgrind instructions per iteration after warmup.
# Run under `valgrind --tool=callgrind --instr-atstart=no`, with the
# bench/callgrind.c extension on the load path (-I DIR). Measures an empty
# window and a K-iteration window in the same process; the Ir per iteration is
# (Ir_K - Ir_0) / K from the two client dumps (.1 and .2), which removes the seam.
# CG_NO_GC=1 stops counting inside GC segments (bench/callgrind.c), so where a
# collection lands in the window does not decide the result.
require "lowrail_callgrind"
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MEASURE_ITRS = Integer(ENV.fetch("MEASURE_ITRS", 3))
NO_GC = ENV["CG_NO_GC"] == "1"

puts RUBY_DESCRIPTION

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  3.times { GC.start }
  LowrailCallgrindBench.start(NO_GC)
  LowrailCallgrindBench.finish
  3.times { GC.start }
  LowrailCallgrindBench.start(NO_GC)
  MEASURE_ITRS.times { block.call }
  LowrailCallgrindBench.finish
  puts "CALLGRIND windows 0 #{MEASURE_ITRS}"
end
