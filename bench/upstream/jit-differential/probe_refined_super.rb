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
