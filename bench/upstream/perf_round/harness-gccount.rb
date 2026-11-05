# Warm up like ruby_bench_ir (2 + 1 iterations), then count minor/major GCs over 3 more.
require_relative "../lib/harness"
def run_benchmark(_hint, **)
  3.times { yield }
  a = GC.stat.slice(:minor_gc_count, :major_gc_count)
  3.times { yield }
  b = GC.stat.slice(:minor_gc_count, :major_gc_count)
  File.write(ENV.fetch("GC_OUT"), "#{b[:minor_gc_count] - a[:minor_gc_count]} minor #{b[:major_gc_count] - a[:major_gc_count]} major\n")
end
