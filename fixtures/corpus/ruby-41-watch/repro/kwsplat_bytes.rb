require "objspace"
def m(**kw) = kw
class P; def d(e, url_safe: false) = e; end
class C < P; def d(e, url_safe: true) = super; end
def count
  yield
  GC.disable
  b = GC.stat(:total_allocated_objects); mb = GC.stat(:malloc_increase_bytes)
  1000.times { yield }
  [(GC.stat(:total_allocated_objects) - b) / 1000.0]
ensure
  GC.enable
end
v = 2; c = C.new
hs = { 1 => {k: 1}, 3 => {k: 1, l: 2, n: 3}, 7 => (1..7).to_h { [:"k#{_1}", _1] }, 0 => {} }
hs.each do |n, h|
  r = m(a: v, **h)
  printf("m(a: v, **h%d)      objs %.2f  memsize %4d  st? %s\n", n, count { m(a: v, **h) }[0], ObjectSpace.memsize_of(r), ObjectSpace.memsize_of(r) > 200)
  r = m(a: v, b: v, c: v, **h)
  printf("m(a:,b:,c:, **h%d)  objs %.2f  memsize %4d\n", n, count { m(a: v, b: v, c: v, **h) }[0], ObjectSpace.memsize_of(r))
end
printf("zsuper kw            objs %.2f\n", count { c.d(1) }[0])
# semantics: the caller's hash is not mutated, the result is a fresh hash
h = {k: 1}; r = m(a: v, **h); raise "mutated" unless h == {k: 1} && !r.equal?(h) && r == {a: 2, k: 1}
x = {k: 1}; y = {a: v, **x}; raise "literal" unless x == {k: 1} && y == {a: 2, k: 1}
puts "semantics ok"
