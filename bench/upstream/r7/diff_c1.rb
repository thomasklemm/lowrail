# Differential harness for C1: run in main and in the candidate worktree, diff the output.
require "action_view"
include ActionView::Helpers::TagHelper

LOG = []
class Rec
  def initialize(name, present: true, str: nil, raise_on: nil, &hook) = (@n, @p, @s, @r, @h = name, present, str, raise_on, hook)
  def present? = (LOG << "#{@n}.present?"; raise "boom #{@n}" if @r == :present; @h&.call(:present); @p)
  def to_s = (LOG << "#{@n}.to_s"; raise ArgumentError, "to_s #{@n}" if @r == :to_s; @h&.call(:to_s); @s || @n)
  def to_ary = (LOG << "#{@n}.to_ary"; ["never"])
  def to_a = (LOG << "#{@n}.to_a"; ["never"])
  def inspect = "Rec(#{@n})"
end
class SubArray < Array
  def each(...) = (LOG << "SubArray#each"; super)
  def to_a = (LOG << "SubArray#to_a"; ["sub-to_a"])
  def map(...) = (LOG << "SubArray#map"; super)
  def size = (LOG << "SubArray#size"; 99)
end
class SubHash < Hash
  def each(...) = (LOG << "SubHash#each"; super)
  def each_pair(...) = (LOG << "SubHash#each_pair"; super)
end
class Key
  def initialize(n) = @n = n
  def present? = (LOG << "key #{@n}.present?"; true)
  def to_s = (LOG << "key #{@n}.to_s"; @n)
  def hash = @n.hash
  def eql?(o) = o.is_a?(Key) && o.to_s == @n
end

def singleton_array
  a = ["s1", "s2"]
  def a.each(...) = (LOG << "singleton each"; super)
  def a.to_a = (LOG << "singleton to_a"; ["x"])
  a
end

outer = nil
mutating = Rec.new("mut") { |m| outer << "late" if m == :to_s && outer.size < 6 }
sh = SubHash.new; sh["sk1"] = true; sh["sk2"] = false
inputs = {
  "plain" => ["a", "b c"],
  "nested" => ["a", ["b", ["c", { d: true, e: false }]]],
  "recs" => [Rec.new("r1"), [Rec.new("r2", present: false), Rec.new("r3", str: "x&amp;y")]],
  "subarray" => [SubArray["s1", SubArray["s2"]]],
  "subhash" => [sh],
  "singleton" => [singleton_array],
  "keys" => [{ Key.new("k1") => true, Key.new("k2") => nil }],
  "frozen" => [["f1", "f2"].freeze, { f3: true }.freeze],
  "mutate" => (outer = ["m0", mutating, ["m2"]]; [outer]),
  "raise present" => [["ok", Rec.new("rp", raise_on: :present), "after"]],
  "raise to_s" => [["ok", Rec.new("rt", raise_on: :to_s), "after"]],
  "nil false" => [nil, false, [nil, [false]], 0],
  "html" => ["<b>", ["a&b", { "<i>" => true }]],
}
inputs.each do |name, args|
  {
    "token_list" => -> { token_list(*args) },
    "class attr" => -> { tag.div(class: args) },
    "class attr first" => -> { tag.div(class: args.first) },
    "aria" => -> { tag.div(aria: { labelledby: args }) },
    "content_tag" => -> { content_tag(:span, "x", class: args) },
  }.each do |how, f|
    LOG.clear
    outer.replace(["m0", mutating, ["m2"]]) if name == "mutate"
    r = begin
      f.().inspect
    rescue => e
      "#{e.class}: #{e.message}"
    end
    puts "#{name} | #{how} | #{r} | #{LOG.join(", ")}"
  end
end
