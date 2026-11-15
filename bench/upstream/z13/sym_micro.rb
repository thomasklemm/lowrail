# Z13 Symbol block micro: Ir per call of a 10-element Array#map/#each with &:foo vs a block literal, and of a
# method that passes &:foo to an ISEQ callee that yields once. One Callgrind window per case (dumps 2..N+1).
require "lowrail_callgrind"
class Foo
  def initialize(i) = @i = i
  def foo = @i
end
A = Array.new(10) { Foo.new(_1) }
X = Foo.new(1)
def one(x) = yield(x)
CASES = {
  "map(&:foo)" => -> { A.map(&:foo) },
  "map { _1.foo }" => -> { A.map { |x| x.foo } },
  "each(&:foo)" => -> { A.each(&:foo) },
  "each { _1.foo }" => -> { A.each { |x| x.foo } },
  "one(x, &:foo)" => -> { one(X, &:foo) },
  "one(x) { _1.foo }" => -> { one(X) { |x| x.foo } },
}
N = 1000
CASES.each_value { |c| 300.times { c.() } }
3.times { GC.start }
LowrailCallgrindBench.start; LowrailCallgrindBench.finish
CASES.each_value do |c|
  GC.disable
  LowrailCallgrindBench.start
  N.times { c.() }
  LowrailCallgrindBench.finish
  GC.enable
end
File.write(ENV.fetch("OUT"), CASES.keys.join("\n") + "\n")
