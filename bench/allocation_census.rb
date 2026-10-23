# frozen_string_literal: true

require "objspace"

# Bounded, separate discovery phase. Never use tracing as a timing arm.
module AllocationCensus
  def self.capture(n, normalize: ->(file) { file || "<no Ruby source>" })
    raise "positive census size required" unless n.positive?
    3.times { GC.start }
    ObjectSpace.trace_object_allocations_clear
    raise "GC was disabled" if GC.disable
    generation = GC.count
    before = GC.stat(:total_allocated_objects)
    begin
      ObjectSpace.trace_object_allocations_start
      n.times { yield }
      ObjectSpace.trace_object_allocations_stop
      allocated = GC.stat(:total_allocated_objects) - before
      census = lambda do
        rows = Hash.new(0)
        ObjectSpace.each_object do |object|
          next unless ObjectSpace.allocation_generation(object) == generation
          type = case object
          when String then "String"
          when Hash then "Hash"
          when Array then "Array"
          when Proc then "Proc"
          else "other"
          end
          rows[[normalize.call(ObjectSpace.allocation_sourcefile(object)),
            ObjectSpace.allocation_sourceline(object), object.class&.name || "<anonymous/classless>", type]] += 1
        end
        rows
      end
      all = census.call
      # FREEOBJ metadata must remain active during GC to avoid stale addresses.
      ObjectSpace.trace_object_allocations_start
      GC.enable
      3.times { GC.start }
      ObjectSpace.trace_object_allocations_stop
      retained = census.call
      raise "retained census changed identity" unless (retained.keys - all.keys).empty?
      rows = all.sort_by { |key, count| [-count, key.to_s] }.map do |(file, line, klass, type), count|
        { file: file, line: line, class: klass, type: type, allocated: count,
          retained: retained.fetch([file, line, klass, type], 0) }
      end
      { trace_gc_allocations: allocated, enumerated: all.values.sum, retained: retained.values.sum,
        unenumerated: allocated - all.values.sum, callsites: rows,
        types: rows.group_by { _1[:type] }.transform_values { |group|
          { allocated: group.sum { _1[:allocated] }, retained: group.sum { _1[:retained] } } } }
    ensure
      ObjectSpace.trace_object_allocations_stop
      ObjectSpace.trace_object_allocations_clear
      GC.enable
    end
  end
end
