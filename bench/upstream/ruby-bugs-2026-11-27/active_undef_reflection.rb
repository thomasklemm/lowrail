class C; def foo = :c; end
using Module.new { refine(C) { undef_method :foo } }
c = C.new
p((c.foo rescue $!.class))
p((c.send(:foo) rescue $!.class))
p((c.method(:foo).call rescue $!.class))
p c.respond_to?(:foo)
