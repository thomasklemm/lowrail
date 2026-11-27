class C; def foo = :C; private def bar = :b; end
module M; end
class D < C; include M; end
Module.new { refine(M) { def foo = :M; def bar = 1; def baz = 2 } }
p D.method_defined?(:foo), D.public_method_defined?(:foo), D.private_method_defined?(:bar), D.method_defined?(:baz)
class D; alias_method :foo2, :foo; end
p D.new.foo2, D.instance_method(:foo2).owner
class D; undef_method :foo; end
p D.new.respond_to?(:foo), (D.new.foo rescue $!.class), C.new.foo
p((Class.new(D) { undef_method :baz } rescue $!.class))
p((Class.new(D) { alias_method :x, :baz } rescue $!.class))
using Module.new { refine(M) { def qux = 3 } }
p D.new.foo2
