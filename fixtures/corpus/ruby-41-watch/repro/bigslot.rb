# Exit 1 when transient ~700-byte objects make a sparse large-slot heap force "nofree" major GCs.
keep = Array.new(300_000) { |i| i.even? ? "k#{i}" : [i] }
big = Integer(ENV.fetch("BIG", "90"))        # Array.new(90) is embedded in a 768 B slot on master
ring = Array.new(Integer(ENV.fetch("RING", "300"))); pos = 0
# Each big object outlives a few minor GCs (gets promoted), then dies.
iter = -> { 2000.times { |i| "s#{i}"; [i, i] }; ring[pos] = Array.new(big, 0); pos = (pos + 1) % ring.size }
2000.times { iter.() }; GC.start
heap_of = -> { GC.stat_heap.values.find { |h| h[:slot_size] >= big * 8 + 16 } }
f0 = heap_of.()[:force_major_gc_count]
m0 = GC.stat(:major_gc_count); c0 = GC.count
by = Hash.new(0)
n = Integer(ENV.fetch("N", "20000"))
n.times { m = GC.stat(:major_gc_count); iter.(); by[GC.latest_gc_info(:major_by)] += 1 if GC.stat(:major_gc_count) != m }
heap = heap_of.()
puts format("%s: %d GCs, %d major %p; %d B heap: %d pages, force_major %d", RUBY_VERSION, GC.count - c0,
  GC.stat(:major_gc_count) - m0, by, heap[:slot_size], heap[:heap_eden_pages], heap[:force_major_gc_count] - f0)
if ENV["BISECT"] # 4.0.7 runs 2 nofree majors here, master 26-29
  exit(by[:nofree] <= 8 ? 0 : by[:nofree] >= 15 ? 1 : 125)
end
exit(by[:nofree] > 0 ? 1 : 0)
