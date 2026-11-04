def m(**kw) = kw
def b = nil
def allocs; yield; yield; GC.disable; x = GC.stat(:total_allocated_objects); yield; y = GC.stat(:total_allocated_objects); GC.enable; y - x; end
hs = (0..9).map { |n| (1..n).to_h { |i| [:"k#{i}", i] } }
p hs.map { |h| allocs { m(**h, &b) } }
