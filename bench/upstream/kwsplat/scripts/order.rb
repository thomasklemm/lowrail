def m(**kw) = kw
k = +"a"; p m(k => 1, **(k << "x"; {}))
k = +"a"; p m(k => 1, **(k << "x"; {b: 1, c: 2, d: 3}))
log = []
key = Object.new; key.define_singleton_method(:hash) { log << :hash; 1 }
splat = Object.new; splat.define_singleton_method(:to_hash) { log << :to_hash; {z: 1} }
m(key => 1, **(log << :splat; splat)); p log.uniq
log.clear
splat3 = Object.new; splat3.define_singleton_method(:to_hash) { log << :to_hash; {x: 1, y: 2, z: 3} }
m(key => 1, **(log << :splat; splat3)); p log
log.clear
bad = Object.new; bad.define_singleton_method(:to_hash) { raise "boom" }
begin; m(key => 1, **bad); rescue => e; end; p log
k = [1]; h = m(k => 1, **(k << 2; {})); p h.key?([1, 2])
k = [1]; h = m(k => 1, **(k << 2; {b: 1, c: 2, d: 3})); p [h.key?([1, 2]), h.key?([1]), h.keys]
