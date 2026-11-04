def m(**kw) = kw
log = []
key = Object.new; key.define_singleton_method(:hash) { log << :hash; 1 }
big = (1..9).to_h { [:"k#{_1}", _1] }
s = Object.new; s.define_singleton_method(:to_hash) { log << :to_hash; big }
m(key => 1, **(log << :splat; s)); p log
k = [1]; h = m(k => 1, **(k << 2; big)); p [h.key?([1, 2]), h.key?([1])]
