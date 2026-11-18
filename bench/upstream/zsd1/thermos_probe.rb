require "objspace"

def copy_arg(s) = s.dup
def signature(s)
  [s.class.name, s.bytes, s.encoding.name, s.frozen?, s.valid_encoding?,
   s.ascii_only?, s.instance_variables.sort.map { |v| [v, s.instance_variable_get(v)] }]
end
def record(label, value) = puts([label, value].inspect)
def warm(name)
  16.times { send(name) }
end

# Each constant has its own compiled call site, including both embedded-copy sizes.
lengths = [0, 1, 7, 8, 23, 24, 119, 120, 127, 128, 129, 231, 232, 255, 256, 257, 300, 500, 1000, 3000]
lengths.each_with_index do |n, i|
  [:mutable, :frozen].each do |kind|
    name = "thermos_#{kind}_#{i}"
    c = "THERMOS_#{kind.upcase}_#{i}"
    str = ("a" * n)
    str.freeze if kind == :frozen
    Object.const_set(c, str)
    eval("def #{name} = #{c}.dup", TOPLEVEL_BINDING, __FILE__, __LINE__)
    warm(name)
    if kind == :mutable
      str.replace("é\0x" * (n % 5 + 1))
      str.force_encoding("BINARY")
    else
      str.hash
      str.ascii_only?
    end
    dup = send(name)
    raise "alias or frozen" if dup.equal?(str) || dup.frozen?
    raise "wrong bytes or encoding" unless dup.bytes == str.bytes && dup.encoding == str.encoding
    record(name, signature(dup))
  end
end

# Exercise compiled constant paths before tracing or singleton invalidation.
GC.verify_compaction_references(double_heap: true, toward: :empty)
record(:early_compact, lengths.each_index.all? do |i|
  [:mutable, :frozen].all? do |kind|
    src = Object.const_get("THERMOS_#{kind.upcase}_#{i}")
    dup = send("thermos_#{kind}_#{i}")
    dup.bytes == src.bytes && dup.encoding == src.encoding && !dup.frozen? && !dup.equal?(src)
  end
end)
old_stress = GC.stress
begin
  GC.stress = true
  3.times { raise "compiled stress" unless thermos_frozen_15.bytesize == 257 && thermos_mutable_0.bytes == [195, 169, 0, 120] }
ensure
  GC.stress = old_stress
end
record(:early_stress, :ok)

LATE = +"abc"
def late_copy = LATE.dup
def constant_reader = LATE
def reader_copy = constant_reader.dup
def via_array = [LATE].first.dup
def via_kw = LATE.dup(**{})
def via_block = LATE.dup { raise "block called" }
names = [:late_copy, :reader_copy, :via_array, :via_kw, :via_block]
names.each { warm(it) }
[
  -> { LATE << "!" },
  -> { LATE.replace("\xff\0".b).force_encoding("UTF-8") },
  -> { LATE.force_encoding("UTF-16LE") },
  -> { LATE.replace("q" * 4000) },
  -> { LATE.slice!(0, 3500) },
  -> { LATE.instance_variable_set(:@late, 17) },
  -> { LATE.remove_instance_variable(:@late) },
  -> { LATE.freeze }
].each_with_index do |change, i|
  change.call
  names.each { record([i, it], signature(send(it))) }
end

# Frozen containers can fold a mutable element to Const without freezing it.
FROZEN_ARRAY = [+"array child"].freeze
FROZEN_HASH = { child: +"hash child" }.freeze
def array_child_copy = FROZEN_ARRAY[0].dup
def hash_child_copy = FROZEN_HASH[:child].dup
[:array_child_copy, :hash_child_copy].each { warm(it) }
FROZEN_ARRAY[0].replace("é\0" * 20).force_encoding("BINARY")
FROZEN_HASH[:child].replace("hash changed" * 40)
record(:array_child, signature(array_child_copy))
record(:hash_child, signature(hash_child_copy))
FROZEN_ARRAY[0].instance_variable_set(:@child, 31)
FROZEN_HASH[:child].instance_variable_set(:@child, 47)
record(:array_child_ivars, signature(array_child_copy))
record(:hash_child_ivars, signature(hash_child_copy))

16.times { copy_arg(+"warm") }
s = +"late"
copy_arg(s)
s.instance_variable_set(:@a, 1)
record(:late_ivar, signature(copy_arg(s)))
s.remove_instance_variable(:@a)
record(:removed_ivar, signature(copy_arg(s)))
80.times { |i| s.instance_variable_set(:"@v#{i}", i) }
record(:many_ivars, signature(copy_arg(s)))
80.times { |i| s.remove_instance_variable(:"@v#{i}") }
record(:removed_many, signature(copy_arg(s)))
s.singleton_class
record(:empty_singleton, signature(copy_arg(s)))
def s.initialize_dup(other)
  super
  @hook = :called
end
record(:singleton_hook, signature(copy_arg(s)))
def s.dup = :singleton_dup
record(:singleton_dup, copy_arg(s))
s.singleton_class.remove_method(:dup)
record(:singleton_restore, signature(copy_arg(s)))

Encoding.list.each do |enc|
  source = "\xff\x00a".b.force_encoding(enc)
  dup = copy_arg(source)
  raise "encoding #{enc}" unless dup.bytes == source.bytes && dup.encoding == enc
end
record(:all_encodings, Encoding.list.size)

big = "x" * 6000
shared = big[100, 4000]
copy = copy_arg(shared)
big.replace("z" * 6000)
shared[0] = "Q"
copy[-1] = "C"
record(:sharing, [big[0], shared[0], shared[-1], copy[0], copy[-1]])

eval("# frozen_string_literal: true\ndef frozen_literal_copy = 'frozen'.dup", TOPLEVEL_BINDING)
eval("# frozen_string_literal: false\ndef mutable_literal_copy = 'mutable'.dup", TOPLEVEL_BINDING)
eval("def chilled_literal_copy = 'chilled'.dup", TOPLEVEL_BINDING)
[:frozen_literal_copy, :mutable_literal_copy, :chilled_literal_copy].each do |m|
  warm(m)
  x = send(m)
  x << "!"
  record(m, signature(x))
end

TRACE_CONST = "trace constant".freeze
def trace_const_copy = TRACE_CONST.dup
warm(:trace_const_copy)
ObjectSpace.trace_object_allocations_start
ObjectSpace.trace_object_allocations_clear
[:trace_const_copy, :late_copy].each do |m|
  x = send(m)
  record([:allocation, m], [!ObjectSpace.allocation_sourcefile(x).nil?, ObjectSpace.allocation_method_id(x)])
end
ObjectSpace.trace_object_allocations_stop
ObjectSpace.trace_object_allocations_clear
counts = Hash.new(0)
tp = TracePoint.new(:c_call, :c_return) { |t| counts[t.event] += 1 if t.method_id == :dup }
tp.enable { 6.times { copy_arg(+"traced"); trace_const_copy } }
record(:tracepoint, counts.sort)

GC.verify_compaction_references(double_heap: true, toward: :empty)
record(:compact, [signature(trace_const_copy), signature(late_copy)])
old_stress = GC.stress
begin
  GC.stress = true
  3.times { raise "stress" unless trace_const_copy == TRACE_CONST && copy_arg(+"stress") == "stress" }
ensure
  GC.stress = old_stress
end
record(:stress, :ok)

class CopySub < String
  def initialize_copy(other)
    super
    @copied = 23
  end
end
record(:subclass, signature(copy_arg(CopySub.new("sub"))))
begin
  copy_arg("a").dup(1)
rescue ArgumentError => e
  record(:argument_error, e.class.name)
end
module ThermosRefinement
  refine String do
    def dup = :refined
  end
end
module ThermosRefinementUse
  using ThermosRefinement
  def self.copy(s) = s.dup
end
16.times { ThermosRefinementUse.copy("r") }
record(:refinement, ThermosRefinementUse.copy("r"))

module ThermosPrepend
  def dup = [:prepended, super]
end
String.prepend(ThermosPrepend)
record(:prepend, copy_arg(+"p"))
ThermosPrepend.remove_method(:dup)
record(:prepend_removed, signature(copy_arg(+"p")))
class String
  alias_method :thermos_original_dup, :dup
  def dup = :redefined
end
record(:redefined, [copy_arg(+"r"), trace_const_copy])
class String
  alias_method :dup, :thermos_original_dup
  remove_method :thermos_original_dup
end
record(:restored, [signature(copy_arg(+"r")), signature(trace_const_copy)])

SHARE_CONST = Ractor.make_shareable("share" * 60)
def share_const_copy = SHARE_CONST.dup
warm(:share_const_copy)
record(:ractor, Ractor.new {
  a = Array.new(16) { share_const_copy }
  x = a.last
  x << "!"
  [x.bytesize, x.frozen?, SHARE_CONST.bytesize, a.map(&:object_id).uniq.size]
}.value)
record(:after_ractor, signature(share_const_copy))
