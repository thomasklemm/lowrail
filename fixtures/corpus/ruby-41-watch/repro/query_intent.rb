# rails runner in a census Fizzy copy: QueryIntent and Card slot sizes after warmup.
require "objspace"
ids = Card.limit(20).pluck(:id)
300.times { |i| Card.find(ids[i % ids.size]).title }
GC.start; GC.disable
heaps = GC.stat_heap.keys
before = heaps.to_h { [_1, GC.stat_heap(_1, :total_allocated_objects)] }
objs = []
ObjectSpace.trace_object_allocations { 20.times { |i| objs << Card.find(ids[i % ids.size]) } }
qis = ObjectSpace.each_object(ActiveRecord::ConnectionAdapters::QueryIntent).select { ObjectSpace.allocation_sourcefile(_1) }
q = qis.first
puts "#{RUBY_VERSION}: QueryIntent per find #{qis.size / 20.0}, ivars #{q.instance_variables.size}, memsize #{ObjectSpace.memsize_of(q)}; Card ivars #{objs[0].instance_variables.size}, memsize #{ObjectSpace.memsize_of(objs[0])}"
puts "  slot allocations per find: " + heaps.filter_map { d = GC.stat_heap(_1, :total_allocated_objects) - before[_1]; "#{GC.stat_heap(_1, :slot_size)}B:#{(d / 20.0).round(1)}" if d > 0 }.join(" ")
