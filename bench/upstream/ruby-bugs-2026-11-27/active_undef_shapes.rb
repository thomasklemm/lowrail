class P; def foo = :parent; end
module M; end; class C < P; include M; end
module M2; def foo = :m2; end; class C2 < P; include M2; end
class C3 < P; end
class C4 < P; def foo = :c4; end
module R
  refine(M) { def foo = 1; undef_method :foo }
  refine(M2) { def foo = 1; undef_method :foo }
  refine(C3) { def foo = 1; undef_method :foo }
  refine(C4) { def foo = 1; undef_method :foo }
end
o = {"C"=>C, "C2"=>C2, "C3"=>C3, "C4"=>C4}.fetch(ARGV[0]).new
using R
case ARGV[1]
when "call" then p((o.foo rescue $!.class))
when "send" then p((o.send(:foo) rescue $!.class))
when "method" then p((o.method(:foo).call rescue $!.class))
when "respond" then p o.respond_to?(:foo)
end
