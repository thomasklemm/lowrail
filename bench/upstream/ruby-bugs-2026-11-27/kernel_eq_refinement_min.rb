Module.new { refine(Kernel) { def ==(other) = true } }
class Foo; end
p Foo.new != 1
