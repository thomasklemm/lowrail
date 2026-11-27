module M; def foo = :m; end
class C; include M; end
using Module.new { refine(M) { undef_method :foo } }
c = C.new
p((c.foo rescue $!.class))
p((c.public_send(:foo) rescue $!.class))
p((c.method(:foo).call rescue $!.class))
p c.respond_to?(:foo)
