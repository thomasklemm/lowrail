require_relative "../lib/harness"

# Local ruby-bench harness: objects allocated per iteration by source line and
# class, after warmup, for comparing a JIT with the interpreter. Writes
# {"file:line class" => objects per iteration} to $ALLOC_SITES_JSON.
# Allocation tracing enables a NEWOBJ hook, which invalidates ZJIT code that
# assumed none; the traced iterations run recompiled code (as in the census).
require "objspace"
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 10))
TRACED_ITRS = Integer(ENV.fetch("TRACED_ITRS", 3))

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  ObjectSpace.trace_object_allocations_start
  2.times { block.call } # recompile after the NEWOBJ hook invalidation
  GC.start
  GC.disable
  ObjectSpace.trace_object_allocations_clear
  before = GC.stat(:total_allocated_objects)
  TRACED_ITRS.times { block.call }
  total = GC.stat(:total_allocated_objects) - before
  counts = Hash.new(0)
  ObjectSpace.each_object do |o|
    file = ObjectSpace.allocation_sourcefile(o) or next
    counts["#{file.sub(%r{.*/gems/}, "")}:#{ObjectSpace.allocation_sourceline(o)} #{(o.class rescue BasicObject)}"] += 1
  end
  ObjectSpace.trace_object_allocations_stop
  GC.enable
  require "json"
  File.write(ENV.fetch("ALLOC_SITES_JSON"), JSON.generate(total_per_itr: total.fdiv(TRACED_ITRS),
    sites: counts.transform_values { _1.fdiv(TRACED_ITRS) }))
end
