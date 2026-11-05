# Loaded with -r in place of ruby-bench's default harness: runs harness/default.rb
# unchanged and adds, after each iteration, a Callgrind dump (each dump file
# holds one iteration's instructions plus the harness's bookkeeping since the
# previous dump) and one line of GC counters. Needs RUBY_BENCH_DIR; without
# CG_DUMP=0 also the ruby_bench_cg extension on -I.
DUMP = ENV["CG_DUMP"] != "0"
require "ruby_bench_cg" if DUMP
require File.join(ENV.fetch("RUBY_BENCH_DIR"), "harness/default")

def __cg_stat(itr)
  s = GC.stat
  $stdout.puts "CGSTAT #{itr} #{s[:total_allocated_objects]} #{s[:minor_gc_count]} #{s[:major_gc_count]} #{s[:heap_allocated_pages]} #{s[:heap_live_slots]}"
end

alias __cg_default_run_benchmark run_benchmark
def run_benchmark(num_itrs_hint, **kw, &block)
  itr = 0
  RubyBenchCG.dump if DUMP # dump 1: boot
  __cg_stat(itr)
  __cg_default_run_benchmark(num_itrs_hint, **kw) do
    result = block.call
    RubyBenchCG.dump if DUMP
    __cg_stat(itr += 1)
    result
  end
end
