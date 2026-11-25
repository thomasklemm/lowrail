module Doubling
  refine(Integer) { def double = self * 2 }
end
class Integer; def to_refined_or_not = :plain; end
def foo = yield 3
def before = (foo(&:double) rescue $!.class)
r = []
blk = -> { (foo(&:double) rescue $!.class) }
3.times { r << [before, blk.()] }
using Doubling
def after = (foo(&:double) rescue $!.class)
blk2 = -> { (foo(&:double) rescue $!.class) }
3.times { r << [before, blk.(), after, blk2.()] }
r << eval("foo(&:double) rescue $!.class")
m = Module.new { using Doubling; def self.x = foo(&:double) }
3.times { r << m.x }
o = Object.new
3.times { r << o.instance_eval { (foo(&:double) rescue $!.class) } }
r << [1, 2].map(&:double)
p r
