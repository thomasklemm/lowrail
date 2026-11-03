def t(*, **o) = o
class P; def d(e, url_safe: false) = e; def r(e, a: 1, **kw) = kw; end
class C < P; def d(e, url_safe: true) = super; def r(e, a: 2, **kw) = super; end
def count(label) = (GC.disable; a = GC.stat(:total_allocated_objects); 1000.times { yield }; d = GC.stat(:total_allocated_objects) - a; GC.enable; puts format("%-50s %.1f", label, d / 1000.0))
v = true; d = [1]; e = {}; one = {k: 1}; seven = (1..7).to_h { [:"k#{_1}", _1] }; c = C.new; dfl = [1]
count("t(a: v, **{})") { t(a: v, **e) }
count("t(a: v, **{k: 1})") { t(a: v, **one) }
count("t(a: v, b: v, c: v, **{k: 1})") { t(a: v, b: v, c: v, **one) }
count("t(a: v, **h7)") { t(a: v, **seven) }
count("t(count: 1, raise: v, **{}, default: d)") { t(count: 1, raise: v, **e, default: dfl) }
count("t(count: 1, raise: v, **{k: 1}, default: d)") { t(count: 1, raise: v, **one, default: dfl) }
count("t(raise: v, **{}, default: d)") { t(raise: v, **e, default: dfl) }
count("t(a: v, **{}, **{})") { t(a: v, **e, **e) }
count("{a: v, **{}, b: d}") { {a: v, **e, b: dfl} }
count("t(*[], **{}) (single splat)") { t(*d, **e) }
count("t(*[], **{k: 1}) (single splat)") { t(*d, **one) }
count("zsuper with keywords") { c.d(1) }
count("zsuper with keywords and **kw") { c.r(1, z: 1) }
h = {a: 1}; t(a: v, **h); raise "mutated" unless h == {a: 1}
