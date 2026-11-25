# A refined callee small enough to inline into an unrefined caller that has its own speculation.
module Doubling
  refine(Integer) { def double = self * 2 }
end
class Box
  def initialize = (@v = 1)
  attr_reader :v
end
module Refined
  using Doubling
  def self.small(a) = a.sum(&:double)
end
module Plain
  def self.small(a) = a.sum(&:succ)
end
mod = ENV["MOD"] == "plain" ? Plain : Refined
def caller_work(mod, box, a) = box.v + mod.small(a) + box.v * 3
box = Box.new
a = [1, 2, 3]
s = 0
Integer(ENV.fetch("N", "200000")).times { s += caller_work(mod, box, a) }
p s
