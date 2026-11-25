# Implicit-argument super from a method with a keyword parameter into `def m(...) = super`.
class Base
  def m(*args, **kw) = [args, kw]
end
class Middle < Base
  def m(...) = super
end
class Top < Middle
  def m(a, k: nil) = super
end
o = Top.new
100.times do |i|
  got = o.m(1, k: 2)
  raise "iteration #{i}: #{got.inspect}" unless got == [[1], {k: 2}]
end
puts "ok"
