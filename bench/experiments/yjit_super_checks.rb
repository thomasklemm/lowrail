# frozen_string_literal: true

# Y2 counterexamples: run unchanged with base/patch and each of the three VMs.
require "json"
require "weakref"
RESULTS = []

def check(label, expected)
  1_000.times do
    actual = yield
    raise "#{label}: #{actual.inspect} != #{expected.inspect}" unless actual == expected
  end
  RESULTS << [label, expected]
end

class Root
  def self.value(n) = n * 3 + marker
end
class Parent < Root
  def self.value(n) = n * 7 + marker
end
class Child < Parent
  def self.marker = 5
  def self.value(n) = super(n) + 3
end
class Grandchild < Child
  def self.marker = 13
end
check("parent singleton super with subclass self", [22, 37]) { [Child.value(2), Grandchild.value(3)] }

module AncestorLayer
  def value(n) = super(n) + 11
end
Parent.singleton_class.prepend(AncestorLayer)
check("prepend into singleton ancestor", [33, 48]) { [Child.value(2), Grandchild.value(3)] }

module Extension
  def value(n) = super(n) * 2
end
Child.extend(Extension)
check("extend into receiver singleton", [63, 93]) { [Child.value(2), Grandchild.value(3)] }

module Front
  def value(n) = super(n) - 4
end
Child.singleton_class.prepend(Front)
check("prepend into receiver singleton", [59, 89]) { [Child.value(2), Grandchild.value(3)] }

class Parent
  def self.value(n) = n * 11 + marker
end
check("redefine super target", [75, 113]) { [Child.value(2), Grandchild.value(3)] }
Parent.singleton_class.remove_method(:value)
check("remove super target", [43, 65]) { [Child.value(2), Grandchild.value(3)] }
Parent.define_singleton_method(:value) { |n| n * 5 + marker }
check("define_singleton_method super target", [51, 77]) { [Child.value(2), Grandchild.value(3)] }
Parent.singleton_class.undef_method(:value)
check("undef super target", [:value, :value]) do
  [Child, Grandchild].map do |receiver|
    begin
      receiver.value(2)
      :unexpected_success
    rescue NoMethodError => error
      error.name
    end
  end
end
class Parent
  def self.value(n) = n * 5 + marker
end
check("restore super target", [51, 77]) { [Child.value(2), Grandchild.value(3)] }

module Base
  def foo(n) = n * 7
end
module Copied
  include Base
  extend Base
  def foo(n) = super(n) + 3
  module_function :foo
end
module Wrapper
  def foo(n) = super(n) + 7
end
Copied.singleton_class.prepend(Wrapper)
check("module_function copy plus extend and prepend", [17, 38]) { [Copied.foo(1), Copied.foo(4)] }
module Base
  def foo(n) = n * 11
end
check("redefine module super target", [21, 54]) { [Copied.foo(1), Copied.foo(4)] }
module BeforeBase
  def foo(n) = super(n) - 2
end
Base.prepend(BeforeBase)
check("prepend into extended ancestor", [19, 52]) { [Copied.foo(1), Copied.foo(4)] }
Copied.define_singleton_method(:foo) { |n| n * 13 }
check("define singleton method on module", [20, 59]) { [Copied.foo(1), Copied.foo(4)] }
Copied.singleton_class.remove_method(:foo)
check("remove module singleton method", [16, 49]) { [Copied.foo(1), Copied.foo(4)] }

class RefParent
  def self.foo(n) = n * 7
end
class RefChild < RefParent
  def self.foo(n) = super(n) + 3
end
check("unrefined class super", 17) { RefChild.foo(2) }
module Y2Refinement
  refine RefChild.singleton_class do
    def foo(n) = super(n) + 101
  end
end
module RefinedCaller
  using Y2Refinement
  def self.call(n) = RefChild.foo(n)
end
check("refined singleton super", [118, 17]) { [RefinedCaller.call(2), RefChild.foo(2)] }

class Ordinary
  def value(n) = n * 7
end
ordinary = Ordinary.new
def ordinary.value(n) = super(n) + 3
check("ordinary singleton unchanged", 17) { ordinary.value(2) }
GC.verify_compaction_references(double_heap: true, toward: :empty)
check("class after compaction", [51, 77]) { [Child.value(2), Grandchild.value(3)] }
check("module after compaction", [16, 49]) { [Copied.foo(1), Copied.foo(4)] }
check("refinement after compaction", [118, 17]) { [RefinedCaller.call(2), RefChild.foo(2)] }
check("ordinary after compaction", 17) { ordinary.value(2) }
weak = WeakRef.new(ordinary)
ordinary = nil
GC.start
retained = !!weak.weakref_alive?
# Master ZJIT retains this object in both arms; record that control rather
# than treating this YJIT patch as a change to ZJIT's existing policy.
raise "ordinary singleton retained" if retained && !RubyVM::ZJIT.enabled?
RESULTS << ["ordinary singleton collectible", !retained]
puts JSON.generate(RESULTS)
