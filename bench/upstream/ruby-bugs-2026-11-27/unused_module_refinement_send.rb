class C; def foo = :C; end
module M; end
class D < C; include M; end
Module.new { refine(M) { def foo = :M } }
p D.new.foo
p D.new.send(:foo)
