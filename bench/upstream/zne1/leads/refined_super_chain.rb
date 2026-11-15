# Under ZJIT, `super` in a refined method reaches another refinement of the same method once the method is
# compiled. Expected, as in the interpreter: every call returns "FooExt2#y Foo#y".
#   ruby --zjit --zjit-call-threshold=2 refined_super_chain.rb
class Foo
  def y = "Foo#y"
end
module FooExt
  refine(Foo) { def y = "FooExt#y " + super }
end
module FooExt2
  refine(Foo) { def y = "FooExt2#y " + super }
end
module Client
  using FooExt
  using FooExt2
  def self.invoke_y_on(foo) = foo.y
end
foo = Foo.new
puts Array.new(Integer(ARGV[0] || 4)) { Client.invoke_y_on(foo) }.tally
