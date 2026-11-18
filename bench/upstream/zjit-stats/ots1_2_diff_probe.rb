# Differential probe for the OTS1 objtostring arms: run with and without --zjit and diff stdout.
# Each site warms on one type, then sees a mix; later phases redefine Integer#to_s, Module#to_s and
# add singleton to_s methods after the arms compiled.
def site_a(x) = "<#{x}>"
def site_b(x) = "<#{x}>"
def site_c(x) = "<#{x}>"
def site_d(x) = "<#{x}>"

def show(label, s)
  puts [label, s.gsub(/0x\h+/, "0x"), s.encoding, s.frozen?, s.class].inspect
end

anon = Module.new
anon_class = Class.new
named_with_singleton = Module.new
Object.const_set(:OtsNamed, named_with_singleton)
values = ["div", :em, 0, 9, 10, -1, 2**70, nil, true, 1.5, Object, Comparable, anon, anon_class, Class.new(String).new("sub"), "bin".b]

20.times { site_a("div") }
20.times { site_b(1) }
20.times { site_c(Object) }
20.times { site_d(:em) }
3.times do |round|
  values.each_with_index do |v, i|
    show([:a, round, i], site_a(v))
    show([:b, round, i], site_b(v))
    show([:c, round, i], site_c(v))
    show([:d, round, i], site_d(v))
  end
  # Mixed String/Integer/Module so each site goes polymorphic.
  10.times { [1, "x", Object, 3].each { |v| site_a(v); site_b(v); site_c(v); site_d(v) } }
end

def OtsNamed.to_s = "singleton to_s"
values.each_with_index { |v, i| show([:singleton, i], site_c(v)) }
show(:named_singleton, site_c(OtsNamed))
show(:named_singleton_a, site_a(OtsNamed))

class Integer
  alias_method :__ots_to_s, :to_s
  def to_s(*) = "int!"
end
[0, 5, 10, 2**70].each { |v| show([:redef_int, v], site_a(v)); show([:redef_int_b, v], site_b(v)) }
class Integer
  alias_method :to_s, :__ots_to_s
end
[0, 5].each { |v| show([:restored_int, v], site_a(v)) }

class Module
  alias_method :__ots_to_s, :to_s
  def to_s = "mod!"
end
[Object, Comparable, anon].each_with_index { |v, i| show([:redef_mod, i], site_a(v)); show([:redef_mod_c, i], site_c(v)) }
class Module
  alias_method :to_s, :__ots_to_s
end
show(:restored_mod, site_c(Object))
