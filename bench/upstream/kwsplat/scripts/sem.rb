# Semantics of m(a: v, **h): results must match across builds
def m(**kw) = kw
def r2k(*a) = a
class << self; ruby2_keywords def r2kpass(*a) = m(*a); end
out = []
v = 1
h = { b: 2 }.freeze;                  r = m(a: v, **h); out << [r, r.frozen?, r.equal?(h)]
h = Hash.new(5).merge!(b: 2);         r = m(a: v, **h); out << [r, r.default, r.equal?(h)]
h = Hash.new { 9 }.merge!(b: 2);      r = m(a: v, **h); out << [r, r.default_proc.nil?]
h = {}.compare_by_identity; k = "x".dup; h[k] = 1; h["x".dup] = 2
r = m(a: v, **h); out << [r.size, r.compare_by_identity?, r.keys.map(&:frozen?)]
h = (1..9).to_h { [:"k#{_1}", _1] };  r = m(a: v, **h); h[:k1] = 100; h[:new] = 1; out << [r.size, r[:k1], r.key?(:new)]
h = { a: 7 };                         r = m(a: v, **h); out << r      # splat overrides
h = { a: 7 };                         r = m(**h, a: v); out << r
h = (1..3).to_h { [:"k#{_1}", _1] };  r = m(a: v, **h); r[:z] = 1; out << [h.key?(:z), r.size]
h = Hash.ruby2_keywords_hash(b: 2);   r = m(a: v, **h); out << [Hash.ruby2_keywords_hash?(r), r]
r = r2k(a: v, **{b: 2}); out << [Hash.ruby2_keywords_hash?(r.last), r]
r = r2kpass(a: v, **{b: 2}); out << r
o = Object.new; def o.to_hash = { b: 3 }; r = m(a: v, **o); out << r
h = { "s" => 1 }; r = m(a: v, **h); out << [r, r.keys.last.frozen?]
r = m(a: v, **nil); out << r
big = (1..20).to_h { [:"k#{_1}", _1] }; r = m(a: v, b: v, **big); out << [r.size, r.keys.first(3), r.keys.last]
p out
v = 1
h = Hash.new(3).compare_by_identity.merge!(b: 2); x = {a: v, **h}; p [x, x.default, x.compare_by_identity?, x.frozen?]
h = {b: 2}; x = {a: v, **h, c: v}; p x
h = {b: 2}; r = m(**h, &(h[:z] = 1; nil)); p [r, h]
h = {b: 2}; def bm(**kw, &b) = kw; r = bm(**h, &(h.clear; nil)); p r
def kws(a: 0, b: 0, **rest) = [a, b, rest]
h = (1..9).to_h { [:"k#{_1}", _1] }.merge(b: 5); p kws(a: v, **h)
p((begin; m(a: v, **Object.new); rescue TypeError => e; e.class; end))
