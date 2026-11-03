# frozen_string_literal: true

# ruby-bench harness for the ZJIT section of docs/upstream/combined-effect.md:
# Callgrind Ir per iteration after warmup, as bench/upstream/ruby_bench_callgrind.rb
# (an empty window and a MEASURE_ITRS window in the same process; Ir per
# iteration is their difference / MEASURE_ITRS), for byroot/ruby-bench's layout.
# Run under `valgrind --tool=callgrind --instr-atstart=no --smc-check=all-non-file`
# with the bench/callgrind.c extension on the load path. CG_NO_GC=1 excludes GC.
require File.expand_path("../../harness/harness-common", File.dirname(File.expand_path($PROGRAM_NAME)))
require "lowrail_callgrind"

WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MEASURE_ITRS = Integer(ENV.fetch("MEASURE_ITRS", 3))
NO_GC = ENV["CG_NO_GC"] == "1"

def run_benchmark(_hint, **, &block)
  puts RUBY_DESCRIPTION
  WARMUP_ITRS.times { block.call }
  3.times { GC.start }
  LowrailCallgrindBench.start(NO_GC)
  LowrailCallgrindBench.finish
  3.times { GC.start }
  g0 = GC.stat
  LowrailCallgrindBench.start(NO_GC)
  MEASURE_ITRS.times { block.call }
  LowrailCallgrindBench.finish
  g1 = GC.stat
  puts "CALLGRIND windows 0 #{MEASURE_ITRS} gc #{g1[:count] - g0[:count]} objects #{g1[:total_allocated_objects] - g0[:total_allocated_objects]}"
  puts "ZJIT #{defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?}"
end
