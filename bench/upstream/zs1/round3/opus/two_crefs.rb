# One block ISEQ that runs under a refined and an unrefined cref (class_eval with a string vs plain call).
module Doubling
  refine(Integer) { def double = self * 2 }
end
def foo = yield(3)
BLK = proc { [(foo(&:double) rescue $!.class), ([3].flat_map(&:double) rescue $!.class)] }
using Doubling
r = []
20.times { r << BLK.call }
r << eval("foo(&:double)")
p r.uniq
