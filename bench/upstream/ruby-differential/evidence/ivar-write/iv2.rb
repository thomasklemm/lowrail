n = Integer(ARGV[0]); kind = ARGV[1]
k = Class.new do
  def initialize; @a = @b = @c = 1; end
  def none(v) = v
  def get1(v) = @b
  def set1(v) = (@a = v)
  def set3(v) = (@a = v; @b = v; @c = v)
  attr_writer :a
end
o = k.new
f = case kind
when "none" then -> { o.none(1); o.none(2); o.none(3); o.none(4) }
when "get1" then -> { o.get1(1); o.get1(2); o.get1(3); o.get1(4) }
when "set1" then -> { o.set1(1); o.set1(2); o.set1(3); o.set1(4) }
when "set3" then -> { o.set3(1); o.set3(2); o.set3(3); o.set3(4) }
when "attrw" then -> { o.a = 1; o.a = 2; o.a = 3; o.a = 4 }
when "lam" then -> { }
end
200.times { f.() }
n.times { f.() }
