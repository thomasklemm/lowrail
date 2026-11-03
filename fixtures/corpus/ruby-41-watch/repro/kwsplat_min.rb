def m(**kw) = kw
h = { k: 1 }
v = 2
m(a: v, **h)
GC.disable
b = GC.stat(:total_allocated_objects)
1000.times { m(a: v, **h) }
n = (GC.stat(:total_allocated_objects) - b) / 1000.0
puts n
exit(n > 1.5 ? 1 : 0)
