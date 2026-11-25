module Doubling
  refine(Integer) { def double = self * 2 }
end
def foo = yield 3
def foob(&b) = b
module Refined
  using Doubling
  def self.iseq = foo(&:double)
  def self.cfunc = proc(&:double)
  def self.variadic_cfunc = Proc.new(&:double)
end
def plain = [foo(&:succ), foob(&:succ).lambda?, foob(&:succ).equal?(foob(&:succ)), (foo(&:nope) rescue [$!.class, $!.backtrace_locations&.first(3)&.map(&:label)])]
def test = [(Refined.iseq rescue $!.class), (Refined.cfunc.call(3) rescue $!.class), (Refined.variadic_cfunc.call(3) rescue $!.class)]
r = []
5.times { r << test; r << plain }
Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc))
5.times { r << test; r << plain }
class Symbol; def to_proc = proc { |x| [:redef, x] }; end
3.times { r << test; r << plain }
r.each { p _1 }
