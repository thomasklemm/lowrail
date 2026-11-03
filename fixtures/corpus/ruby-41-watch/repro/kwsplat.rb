def m(**kw) = kw
def m2(a, x: 1, **kw) = kw
class P; def d(e, url_safe: false) = e; end
class C < P; def d(e, url_safe: true) = super; end
class Q; def t(*) = 1; end
class R < Q; def t(*) = super.then(&:itself); end
def count
  GC.disable
  yield
  b = GC.stat(:total_allocated_objects)
  1000.times { yield }
  (GC.stat(:total_allocated_objects) - b) / 1000.0
ensure
  GC.enable
end
h = { k: 1 }
h0 = {}
v = 2
c = C.new
r = R.new
rows = {
  "m(a: 1, **h)" => -> { m(a: 1, **h) },
  "m(a: v, **h)" => -> { m(a: v, **h) },
  "m(a: v, b: v, c: v, **h)" => -> { m(a: v, b: v, c: v, **h) },
  "m(a: v, b: v, c: v, **h0)" => -> { m(a: v, b: v, c: v, **h0) },
  "m(**h)" => -> { m(**h) },
  "m(a: v)" => -> { m(a: v) },
  "m2(1, x: v, **h)" => -> { m2(1, x: v, **h) },
  "zsuper kw: c.d(1)" => -> { c.d(1) },
  "super.then(&:itself)" => -> { r.t(1) },
}
rows.each { |name, f| puts format("%-28s %5.2f", name, count(&f)) }
