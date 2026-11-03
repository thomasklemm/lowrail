# frozen_string_literal: true

# index_with heap census over the census-4 apps and workloads.
#   ruby SCRIPT APP NEW_JSON
# Reuses census 4's boot and workloads. Per workload: GC-enabled objects and
# slot bytes per operation (3 x 20 ops), then one GC-disabled window of 10 ops
# with malloc bytes, Hash spills (hashes of at most 8 entries larger than an
# embedded hash of that size), and the hashes and arrays allocated in
# active_support/core_ext/enumerable.rb (index_with).
require_relative "rails_main_census_4"

module IndexWithHeap
  module_function

  def slot_bytes = GC.stat_heap.sum { |_, s| s[:total_allocated_objects] * s[:slot_size] }

  def ideal_sizes
    @ideal_sizes ||= 9.times.to_h { |n| [n, ObjectSpace.memsize_of(n.times.to_h { |i| [i, i] }.dup)] }
  end

  def measure(op)
    c = RailsMainCensus4
    run = -> { op.call.call; c.reset_side_effects }
    50.times { run.call }
    totals = 3.times.map do
      GC.start
      o, b = GC.stat(:total_allocated_objects), slot_bytes
      20.times { run.call }
      [(GC.stat(:total_allocated_objects) - o) / 20.0, (slot_bytes - b) / 20.0]
    end
    ideal = ideal_sizes
    GC.start
    ObjectSpace.trace_object_allocations_clear
    raise "GC already disabled" if GC.disable
    generation = GC.count
    o, b, m = GC.stat(:total_allocated_objects), slot_bytes, GC.stat(:malloc_increase_bytes)
    ObjectSpace.trace_object_allocations_start
    10.times { run.call }
    ObjectSpace.trace_object_allocations_stop
    window = { objects: (GC.stat(:total_allocated_objects) - o) / 10.0, slot_bytes: (slot_bytes - b) / 10.0,
      malloc_bytes: (GC.stat(:malloc_increase_bytes) - m) / 10.0 }
    spills = Hash.new(0)
    iw = Hash.new(0)
    ObjectSpace.each_object(Hash) do |h|
      next unless ObjectSpace.allocation_generation(h) == generation
      enum = ObjectSpace.allocation_sourcefile(h)&.end_with?("active_support/core_ext/enumerable.rb")
      size = h.size
      mem = ObjectSpace.memsize_of(h)
      spilled = size <= 8 && mem > ideal[size]
      spills[:hashes_le8_spilled] += 1 if spilled
      next unless enum
      iw[:hashes] += 1
      iw[size <= 8 ? :hashes_le8 : :hashes_gt8] += 1
      iw[:hashes_le8_spilled] += 1 if spilled
      iw[:hash_memsize] += mem
    end
    ObjectSpace.each_object(Array) do |a|
      next unless ObjectSpace.allocation_generation(a) == generation
      iw[:arrays] += 1 if ObjectSpace.allocation_sourcefile(a)&.end_with?("active_support/core_ext/enumerable.rb")
    end
    GC.enable
    ObjectSpace.trace_object_allocations_clear
    per = ->(h) { h.transform_values { _1 / 10.0 } }
    { workload: op.name, kind: op.kind, gc_enabled_objects_per_op: totals.map(&:first),
      gc_enabled_slot_bytes_per_op: totals.map(&:last), window_per_op: window,
      spills_per_op: per.(spills), enumerable_rb_per_op: per.(iw) }
  ensure
    ObjectSpace.trace_object_allocations_stop
    GC.enable
  end
end

if $PROGRAM_NAME == __FILE__
  name, output = ARGV
  raise "fresh output required" if File.exist?(output)
  RailsMainCensus4.boot(name)
  results = RailsMainCensus4.workloads(name).map { IndexWithHeap.measure(_1) }
  File.write(output, JSON.pretty_generate(app: name, ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?,
    rails: RailsMainCensus4::RAILS_PIN, workloads: results) + "\n")
  puts "#{name}: #{results.size} workloads -> #{output}"
end
