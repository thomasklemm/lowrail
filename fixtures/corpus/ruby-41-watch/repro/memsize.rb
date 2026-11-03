require "objspace"
o = Object.new; s = "x"; s2 = "x" * 100; a = [1]; a8 = Array.new(8, 1); h = {a: 1}; h3 = {a: 1, b: 2, c: 3}; h9 = (1..9).to_h { [_1, _1] }
h_inc = {}; h_inc[:a] = 1; h_inc[:b] = 2; h_inc[:c] = 3
p({obj: ObjectSpace.memsize_of(o), str: ObjectSpace.memsize_of(s), str100: ObjectSpace.memsize_of(s2), ary1: ObjectSpace.memsize_of(a),
  ary8: ObjectSpace.memsize_of(a8), hash1: ObjectSpace.memsize_of(h), hash3: ObjectSpace.memsize_of(h3), hash9: ObjectSpace.memsize_of(h9),
  hash_inc3: ObjectSpace.memsize_of(h_inc), slots: GC.stat_heap.transform_values { _1[:slot_size] }})
