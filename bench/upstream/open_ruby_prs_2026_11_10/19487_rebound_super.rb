class Base; def m(x = nil) = :base; end
class Child < Base
  def m(x = nil) = (x ? super() : proc { super() })
end
class Other; def m = :other; end
b = Child.new.m
100.times { b.call }
p(begin; Other.new.instance_exec(&b); rescue TypeError => e; "TypeError"; end)
