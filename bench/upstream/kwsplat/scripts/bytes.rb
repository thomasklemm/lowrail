# Objects, GC slot bytes allocated, and memsize of the result per call, sizes 0,1,2,3,8
require "objspace"
def m(**kw) = kw
def b = nil
def stat
  n = 0; bytes = 0; i = 0
  while (s = GC.stat_heap(i) rescue nil) && !s.empty?
    n += s[:total_allocated_objects]; bytes += s[:total_allocated_objects] * s[:slot_size]; i += 1
  end
  [n, bytes]
end
def per(reps = 1000)
  yield
  GC.disable
  o0, b0 = stat
  r = nil
  reps.times { r = yield }
  o1, b1 = stat
  GC.enable
  [(o1 - o0) / reps.to_f, (b1 - b0) / reps.to_f, ObjectSpace.memsize_of(r)]
end
v = 1
[0, 1, 2, 3, 8].each do |n|
  h = (1..n).to_h { [:"k#{_1}", _1] }
  c = per { m(a: v, **h) }
  l = per { {a: v, **h} }
  s = per { m(**h, &b) }
  puts "n=#{n} call obj/bytes/memsize #{c.map { _1.round(1) }}  literal #{l.map { _1.round(1) }}  single #{s.map { _1.round(1) }}"
end
