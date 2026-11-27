module M; def foo = :m; end
class C; include M; end
using Module.new { refine(M) { def foo = 1; undef_method :foo } }
o = C.new
o.foo rescue nil
o.send(:foo)
