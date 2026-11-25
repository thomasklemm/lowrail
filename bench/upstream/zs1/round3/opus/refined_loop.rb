# Persistently refined caller: does ZJIT exit at every call after recompiles?
module Doubling
  refine(Integer) { def double = self * 2 }
end
def foo = yield(3)
module Refined
  using Doubling
  def self.iseq = foo(&:double)
  def self.cfunc = [3].flat_map(&:double)
end
n = Integer(ENV.fetch("N", "100000"))
s = 0
n.times { s += Refined.iseq + Refined.cfunc.first }
p s
