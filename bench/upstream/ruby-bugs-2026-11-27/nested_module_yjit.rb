class P
  def foo = :parent
end
module N
  def foo = super
end
module M
  include N
end
class C < P
  include M
end
using Module.new { refine(M) { def foo = :refined; undef_method :foo } }
C.new.send(:foo)
