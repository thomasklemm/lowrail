# RING=200 BIG=70 N=40000 ruby bigslot.rb
keep = Array.new(300_000) { |i| i.even? ? "k#{i}" : [i] }
big = Integer(ENV.fetch("BIG", "90"))
ring = Array.new(Integer(ENV.fetch("RING", "300"))); pos = 0
iter = -> { 2000.times { |i| "s#{i}"; [i, i] }; ring[pos] = Array.new(big, 0); pos = (pos + 1) % ring.size }
2000.times { iter.() }; GC.start
heap_of = -> { GC.stat_heap.values.find { |h| h[:slot_size] >= big * 8 + 16 } }
m0 = GC.stat(:major_gc_count)
by = Hash.new(0)
Integer(ENV.fetch("N", "20000")).times do
  m = GC.stat(:major_gc_count)
  iter.()
  by[GC.latest_gc_info(:major_by)] += 1 if GC.stat(:major_gc_count) != m
end
heap = heap_of.()
puts format("%s: %d major %p; %d B heap: %d pages", RUBY_VERSION, GC.stat(:major_gc_count) - m0, by,
  heap[:slot_size], heap[:heap_eden_pages])
