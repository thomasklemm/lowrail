# Cref-guard exits inside Ractors and around GC.compact, with inlined refined callees.
module Doubling
  refine(Integer) { def double = self * 2 }
end
module Refined
  using Doubling
  def self.small(a) = a.sum(&:double)
end
def work(a) = Refined.small(a) + 1
r = []
3.times { r << work([1, 2]) }
GC.verify_compaction_references(expand_heap: true, toward: :empty)
3.times { r << work([1, 2]) }
rs = 4.times.map { Ractor.new { 50.times.map { Refined.small([1, 2]) }.uniq } }
r << rs.map(&:value)
GC.compact
r << 10.times.map { work([3]) }.uniq
p r
