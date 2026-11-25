# A method under `using` with a Symbol block arg plus other speculated work (ivar read,
# Integer arithmetic). Compare compile/exit counters and no_side_exits fallbacks.
module Doubling
  refine(Integer) { def double = self * 2 }
end
class Box
  def initialize = (@v = 1)
  attr_reader :v
end
module Refined
  using Doubling
  def self.work(box, a) = box.v + a.sum(&:double) + box.v * 3
end
module Plain
  def self.work(box, a) = box.v + a.sum(&:succ) + box.v * 3
end
mod = ENV["MOD"] == "plain" ? Plain : Refined
box = Box.new
a = [1, 2, 3]
s = 0
Integer(ENV.fetch("N", "200000")).times { s += mod.work(box, a) }
p s
