# Refinements appearing mid-run at top level, in eval, and via Module#refine changes
module R1; refine(Integer) { def ten = self + 10 }; end
def foo = yield(3)
t = -> { (foo(&:ten) rescue $!.class) }
r = []
3.times { r << t.() }
using R1
3.times { r << t.() }
module R1; refine(Integer) { def ten = self + 100 }; end
3.times { r << t.() }
p r
