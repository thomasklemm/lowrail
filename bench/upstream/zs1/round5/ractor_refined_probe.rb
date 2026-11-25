# Two Ractors run the same refined Symbol-block send, so both can take the cref guard's exit and set the
# ISEQ's exited_for_block_arg_refinements bit at once. Prints the results; must match the interpreter.
Warning[:experimental] = false
module Doubling
  refine(Integer) { def double = self * 2 }
end
module Refined
  using Doubling
  def self.work(a) = a.sum(&:double) + a.map(&:double).sum
end
n = Integer(ENV.fetch("N", "20000"))
rs = 2.times.map { Ractor.new(n) { |n| s = 0; n.times { s += Refined.work([1, 2, 3]) }; s } }
p rs.map(&:value), Refined.work([1, 2, 3])
