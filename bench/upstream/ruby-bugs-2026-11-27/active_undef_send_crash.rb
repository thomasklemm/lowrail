module M; def foo = :m; end
class C; include M; end
using Module.new { refine(M) { undef_method :foo } }
p((C.new.foo rescue $!.class))
p C.new.send(:foo)
