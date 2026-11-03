# Exit 1 when an object of a class assigning 34 instance variables in initialize
# (like ActiveRecord::ConnectionAdapters::QueryIntent, 31 on a find) lands in a slot over 320 bytes.
eval "class C34; def initialize; #{(0...34).map { |i| "@i#{i} = #{i}" }.join("; ")}; end; end"
5.times { C34.new }
keep = Array.new(2001)
heaps = GC.stat_heap.keys
before = heaps.to_h { [_1, GC.stat_heap(_1, :total_allocated_objects)] }
i = 0
while i < 2000; keep[i] = C34.new; i += 1; end
heap = heaps.max_by { GC.stat_heap(_1, :total_allocated_objects) - before[_1] }
slot = GC.stat_heap(heap, :slot_size)
puts "34-ivar object slot: #{slot} B (#{GC.stat_heap(heap, :total_allocated_objects) - before[heap]} allocations)"
exit(slot > 320 ? 1 : 0)
