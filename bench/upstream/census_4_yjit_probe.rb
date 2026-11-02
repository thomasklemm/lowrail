# frozen_string_literal: true

# YJIT-only allocation probe (no Rails): ruby [--yjit] SCRIPT. See rails-main-census-4.md.
class Base; def initialize; @a = []; end; end
class Sub < Base; def initialize; super; @b = +""; end; end
class Kw; def initialize(x, y = nil); @x = x; end; end
class Comp; def initialize(*parts); @parts = parts; end; end
def m(l); 300.times { yield }; GC.disable; b = GC.stat(:total_allocated_objects); yield; d = GC.stat(:total_allocated_objects) - b; GC.enable; puts "#{l} #{d}"; end
m("Base.new") { Base.new }
m("Sub.new (zsuper, no args)") { Sub.new }
m("Kw.new(1)") { Kw.new(1) }
m("Comp.new(1, 2)") { Comp.new(1, 2) }
o = Object.new; def o.collector = Comp.new(Base.new, Sub.new)
m("send(:collector)") { o.send(:collector) }
m("collector") { o.collector }
