# Objects allocated by one `m(a: v, **h)` call for h with 0..9 entries, plus variants.
def m(**kw) = kw
def allocs
  yield; yield
  GC.disable
  b = GC.stat(:total_allocated_objects); yield; a = GC.stat(:total_allocated_objects)
  GC.enable
  a - b
end
v = 1
allocs { }; allocs { }
hs = (0..9).map { |n| (1..n).to_h { |i| [:"k#{i}", i] } }
row = ->(&blk) { hs.map { |h| allocs { blk.(h) } } }
puts "m(a: v, **h)          #{row.() { |h| m(a: v, **h) }.inspect}"
puts "m(a: v, b: v, **h)    #{row.() { |h| m(a: v, b: v, **h) }.inspect}"
puts "m(**h) (single splat) #{row.() { |h| m(**h) }.inspect}"
class P; def z(a: 1, b: 2) = nil; end
class C < P; def z(a: 1, b: 2) = super; end
c = C.new
puts "zsuper c.z(a: v)      #{allocs { c.z(a: v) }}"
