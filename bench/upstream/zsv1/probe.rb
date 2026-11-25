# Differential probe for ZSV1: run with and without --zjit at several call thresholds and diff the output.
# Each row exercises setinstancevariable many times (past the profile and compile thresholds) and prints what
# the program observes. Rebuilt on 2026-11-25 from the row list in thermos-review.md; the original probe.rb
# stayed in an archived review orb.
$VERBOSE = nil
ROWS = []
def row(name)
  result = begin
    yield
  rescue Exception => e
    "#{e.class}: #{e.message.gsub(/0x\h+/, '0x?')}"
  end
  ROWS << "#{name}: #{result.inspect}"
end

N = 50

class Plain; def set(v) = (@a = v); def a = @a; end
class Sub < Plain; end
module Ext; def ext = 1; end
module Pre; def set(v) = super(v + 1); end

def make(cls = Plain, extend: false)
  o = cls.new
  o.extend(Ext) if extend
  o
end

row("return value") { o = make(extend: true); (1..N).map { |i| o.set(i) }.sum }
row("stored value") { o = make(extend: true); N.times { |i| o.set(i) }; o.a }
row("existing ivar") { o = make(extend: true); o.set(0); N.times { |i| o.set(i * 2) }; o.instance_variables + [o.a] }
row("new ivar") { (1..N).map { o = make(extend: true); o.set(:x); o.instance_variables }.uniq }
row("removed ivar") do
  (1..N).map { o = make(extend: true); o.set(1); o.remove_instance_variable(:@a); o.set(2); [o.instance_variables, o.a] }.uniq
end
row("extended before first profile") do
  objs = (1..N).map { make(extend: true) }
  objs.each_with_index { |o, i| o.set(i) }
  objs.map(&:a).sum
end
row("ordinary class") { (1..N).map { |i| o = make; o.set(i); o.a }.sum }
row("subclass") { (1..N).map { |i| o = make(Sub, extend: i.odd?); o.set(i); [o.class, o.a] }.last(2) }
row("mixed classes") do
  (1..N).map { |i| o = make([Plain, Sub][i % 2], extend: i % 3 == 0); o.set(i); o.singleton_class.include?(Ext) ? o.a : 0 }.sum
end
row("raising singleton class override") do
  (1..N).map do |i|
    o = make(extend: true)
    def o.class = raise("class called")
    o.set(i)
    o.a
  end.sum
end
row("late extension") do
  objs = (1..N).map { make }
  objs.each_with_index { |o, i| o.set(i) }
  objs.each { |o| o.extend(Ext) }
  objs.each_with_index { |o, i| o.set(-i) }
  objs.map(&:a).sum
end
row("late prepend") do
  objs = (1..N).map { make(extend: true) }
  objs.each_with_index { |o, i| o.set(i) }
  objs.each { |o| o.singleton_class.prepend(Pre) }
  objs.each_with_index { |o, i| o.set(i) }
  objs.map(&:a).sum
end
[0, 1, 3, 10, 70, 150].each do |extra|
  row("#{extra} extra ivars") do
    (1..N).map do |i|
      o = make(extend: true)
      extra.times { |j| o.instance_variable_set(:"@x#{j}", j) }
      o.set(i)
      [o.a, o.instance_variables.size, extra.zero? ? nil : o.instance_variable_get(:"@x#{extra - 1}")]
    end.uniq.last
  end
end
row("180 class-shape branches") do
  classes = (1..180).map { Class.new(Plain) }
  classes.each_with_index.map do |c, i|
    o = c.new
    o.extend(Ext) if i.even?
    (i % 7).times { |j| o.instance_variable_set(:"@y#{j}", j) }
    N.times { |k| o.set(k + i) }
    o.a
  end.sum
end
row("heap values across minor GC") do
  objs = (1..N).map { make(extend: true) }
  objs.each_with_index { |o, i| o.set("s#{i}" * 3) }
  GC.start(full_mark: false)
  objs.each { |o| o.set(o.a + "!") }
  GC.start(full_mark: false)
  objs.map(&:a).last
end
row("compaction verify") do
  objs = (1..N).map { make(extend: true) }
  objs.each_with_index { |o, i| o.set([i]) }
  GC.verify_compaction_references(expand_heap: true, toward: :empty) if GC.respond_to?(:verify_compaction_references)
  objs.each_with_index { |o, i| o.set(o.a + [i]) }
  objs.map { |o| o.a.sum }.sum
end
row("anonymous-class GC") do
  sums = 5.times.map do
    c = Class.new { def set(v) = (@a = v); def a = @a }
    objs = (1..N).map { o = c.new; o.extend(Module.new); o }
    objs.each_with_index { |o, i| o.set(i) }
    objs.map(&:a).sum
  end
  GC.start
  sums
end
row("frozen cold") { o = make(extend: true).freeze; o.set(1) }
row("frozen late") do
  o = make(extend: true)
  N.times { |i| o.set(i) }
  o.freeze
  o.set(0)
end
row("frozen new ivar") do
  N.times { o = make(extend: true); o.instance_variable_set(:@b, 1); o.set(1) }
  o = make(extend: true)
  o.instance_variable_set(:@b, 1)
  o.freeze
  o.set(1)
end
row("freezing during RHS") do
  objs = (1..N).map { make(extend: true) }
  objs.each_with_index.map { |o, i| begin; o.set((o.freeze if i == N - 1; i)); rescue FrozenError => e; e.class; end }.last(2)
end
row("growing during RHS") do
  objs = (1..N).map { make(extend: true) }
  objs.map do |o|
    o.set((10.times { |j| o.instance_variable_set(:"@g#{j}", j) }; :v))
    [o.a, o.instance_variables.size]
  end.uniq
end
class Str < String; def set(v) = (@a = v); def a = @a; end
row("String subclass") { (1..N).map { |i| s = Str.new("x"); s.extend(Ext) if i.odd?; s.set(i); s.a }.sum }
class Array; def zsv1_set(v) = (@a = v); def zsv1_a = @a; end
class Module; def zsv1_set(v) = (@a = v); def zsv1_a = @a; end
row("non-T_OBJECT receivers") do
  arrs = (1..N).map { a = []; a.extend(Ext); a }
  arrs.each_with_index { |a, i| a.zsv1_set(i) }
  mods = (1..N).map { Module.new }
  mods.each_with_index { |m, i| m.zsv1_set(i) }
  [arrs.map(&:zsv1_a).sum, mods.map(&:zsv1_a).sum]
end
class Integer; def zsv1_set(v) = (@a = v); end
row("immediate errors") { (1..N).map { |i| begin; i.zsv1_set(i); rescue => e; e.class; end }.uniq }
row("suspended fiber") do
  o = make(extend: true)
  f = Fiber.new { |x| loop { o.set(x); x = Fiber.yield(o.a) } }
  (1..N).map { |i| f.resume(i) }.sum
end
row("thread-local receiver") do
  Thread.new { o = make(extend: true); N.times { |i| o.set(i) }; Thread.current[:o] = o; o.a }.value
end
class RCls; class << self; def set(v) = (@a = v); end; end
row("non-owner Ractor class write") do
  N.times { |i| RCls.set(i) }
  Warning[:experimental] = false
  r = Ractor.new { begin; RCls.set(:r); rescue => e; e.class; end }
  r.respond_to?(:value) ? r.value : r.take
end

puts ROWS
warn "rows: #{ROWS.size}"
