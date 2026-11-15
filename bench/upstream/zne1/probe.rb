# frozen_string_literal: true

# Differential probe for docs/upstream/zjit-not-equal.md: `a != b` at call sites of every morphism,
# before and after redefinitions made while the sites are compiled. Prints one line per call;
# the output must be identical for the interpreter and for ZJIT at any call threshold.
#   ruby probe.rb > interp.txt; ruby --zjit --zjit-call-threshold=1 probe.rb > zjit.txt; cmp interp.txt zjit.txt
LOG = []

class Plain; end
class Other; end
class EqLog
  def ==(other) = (LOG << [:eq, other.class]; equal?(other))
end
class EqNil
  def ==(other) = nil
end
class EqTruthy
  def ==(other) = :yes
end
class EqNotOverridden
  class Result
    def ! = :overridden
  end
  def ==(other) = Result.new
end
class EqRaise
  def ==(other) = raise(ArgumentError, "boom")
end
class Neq
  def !=(other) = (LOG << :neq; :custom)
end
class NoNeq
  undef_method :!=
  def method_missing(name, *args) = [:missing, name, args.size]
  def respond_to_missing?(*) = true
end
class NoEq
  undef_method :==
  def method_missing(name, *args) = (LOG << [:missing, name]; nil)
  def respond_to_missing?(*) = true
end
class PrivateNeq
  private def !=(other) = true
end
class PrivateEq
  private def ==(other) = (LOG << :private_eq; true)
end
class ProtectedEq
  protected def ==(other) = (LOG << :protected_eq; true)
end
class Basic < BasicObject; end
class BasicEq < BasicObject
  def ==(other) = 1
end
class Cmp
  include Comparable
  attr_reader :n
  def initialize(n) = @n = n
  def <=>(other) = other.is_a?(Cmp) ? n <=> other.n : nil
end
Pair = Struct.new(:a, :b)
module Late; end
class WithLate; include Late; end
class Sub < Plain; end

SINGLE = Plain.new
VALUES = {
  nil: nil, true: true, false: false, sym: :aria, sym2: :class, dsym: "dyn#{$$ * 0}amic".to_sym,
  fix: 1, fix2: 2, big: 2**70, flo: 1.5, bigflo: 1.0e300, rat: 1r, str: "x", str2: +"x", arr: [1], hash: {a: 1},
  range: 1..2, plain: Plain.new, plain2: Plain.new, other: Other.new, sub: Sub.new, eqlog: EqLog.new, eqnil: EqNil.new,
  eqtruthy: EqTruthy.new, eqnot: EqNotOverridden.new, eqraise: EqRaise.new, neq: Neq.new, noneq: NoNeq.new,
  noeq: NoEq.new, privneq: PrivateNeq.new, priveq: PrivateEq.new, proteq: ProtectedEq.new, basic: Basic.new,
  basiceq: BasicEq.new, cmp: Cmp.new(1), cmp2: Cmp.new(1), pair: Pair.new(1, 2), pair2: Pair.new(1, 2),
  klass: Plain, mod: Comparable, single: SINGLE, late: WithLate.new, proc: proc {}, obj: Object.new
}.freeze
KEYS = VALUES.keys.freeze

# Receiver sets per site: monomorphic, the tag_options shape, polymorphic, skewed and megamorphic.
SITES = {
  mono_nil: %i[nil], mono_sym: %i[sym], mono_plain: %i[plain], mono_str: %i[str],
  nil_sym: %i[nil nil nil sym sym2 nil], sym_nil: %i[sym nil], plain_other: %i[plain other],
  plain_sub_single: %i[plain sub single], str_fix_nil: %i[str fix nil], eq_mix: %i[eqlog eqnil eqtruthy],
  neq_mix: %i[neq plain nil], missing_mix: %i[noneq noeq plain], visibility_mix: %i[privneq priveq proteq],
  basic_mix: %i[basic basiceq plain], raise_mix: %i[eqraise plain], cmp_mix: %i[cmp pair fix],
  num_mix: %i[fix big flo bigflo], skewed: %i[nil] * 9 + %i[sym], late_mix: %i[late plain],
  klass_mix: %i[klass mod plain], mega: KEYS
}.freeze

SITES.each_key do |name|
  eval "def site_#{name}(a, b) = a != b", binding, __FILE__, __LINE__
  eval "def lit_#{name}(a) = a != :aria && a != :class", binding, __FILE__, __LINE__
  eval "def nil_#{name}(a) = a != nil", binding, __FILE__, __LINE__
  eval "def unused_#{name}(a, b) = (a != b; 5)", binding, __FILE__, __LINE__
end

module Refined
  refine NilClass do
    def !=(other) = :refined_nil
  end
  refine Symbol do
    def ==(other) = (LOG << :refined_sym_eq; false)
  end
  refine Plain do
    def !=(other) = :refined_plain
  end
end
module RefinedSites
  using Refined
  SITES.each_key do |name|
    eval "def self.site_#{name}(a, b) = a != b", binding, __FILE__, __LINE__
  end
end

def show(value)
  case value
  when nil, true, false, Symbol, Integer then value.inspect
  when Array then "[#{value.map { show(_1) }.join(", ")}]"
  else (Object.instance_method(:class).bind_call(value)).name
  end
end

def call(label, recv_key, arg_key)
  LOG.clear
  result =
    begin
      show(yield)
    rescue Exception => e # rubocop:disable Lint/RescueException
      labels = e.backtrace_locations.first(4).map { "#{_1.label}:#{_1.lineno if _1.path == __FILE__}" }
      "#{e.class}: #{e.message.lines.first.chomp.gsub(/0x\h+/, "0x")[0, 80]} @ #{labels.join(" < ")}"
    end
  puts "#{label} #{recv_key} #{arg_key} -> #{result} #{LOG.inspect}"
end

def round(phase)
  SITES.each do |name, receivers|
    args = %i[nil sym plain str fix] + receivers
    # Receivers vary in the inner loop, so the first profiled calls already see all of them.
    3.times do |pass|
      args.each do |a|
        receivers.each do |r|
          call("#{phase} site_#{name}/#{pass}", r, a) { send("site_#{name}", VALUES[r], VALUES[a]) }
          call("#{phase} unused_#{name}/#{pass}", r, a) { send("unused_#{name}", VALUES[r], VALUES[a]) }
          call("#{phase} refined_#{name}/#{pass}", r, a) { RefinedSites.send("site_#{name}", VALUES[r], VALUES[a]) }
          call("#{phase} lit_#{name}/#{pass}", r, :-) { send("lit_#{name}", VALUES[r]) }
          call("#{phase} nil_#{name}/#{pass}", r, :-) { send("nil_#{name}", VALUES[r]) }
        end
      end
    end
    # Receivers the site has not seen: the miss path of every arm.
    (KEYS - receivers).each do |r|
      call("#{phase} site_#{name}/miss", r, :sym) { send("site_#{name}", VALUES[r], VALUES[:sym]) }
      call("#{phase} lit_#{name}/miss", r, :-) { send("lit_#{name}", VALUES[r]) }
    end
  end
end

def traced(phase)
  events = []
  trace = TracePoint.new(:call, :c_call, :return, :c_return) do |tp|
    events << "#{tp.event} #{tp.defined_class.inspect.gsub(/0x\h+/, "0x")}##{tp.method_id}" if %i[!= == !].include?(tp.method_id)
  end
  SITES.each do |name, receivers|
    receivers.uniq.each do |r|
      events.clear
      result = trace.enable { send("site_#{name}", VALUES[r], VALUES[:sym]) rescue $!.class }
      puts "#{phase} trace site_#{name} #{r} -> #{show(result)} #{events.join(", ")}"
    end
  end
end

round "base"
traced "base"

class Plain
  def ==(other) = (LOG << :plain_eq; other.is_a?(Plain))
end
round "plain=="

class NilClass
  def !=(other) = (LOG << :nil_neq; :nil_custom)
end
round "nil!="
class NilClass
  remove_method :!=
end

class Symbol
  def ==(other) = (LOG << :sym_eq; super)
end
round "sym=="
class Symbol
  remove_method :==
end

def SINGLE.!=(other) = :singleton_neq
other_single = VALUES[:other]
def other_single.==(other) = (LOG << :singleton_eq; :singleton)
round "singleton"

module Late
  def !=(other) = :late_neq
end
round "late-module"

module Prepended
  def ==(other) = (LOG << :prepended_eq; super)
end
String.prepend(Prepended)
round "prepend"

module Kernel
  def !=(other) = (LOG << :kernel_neq; !(self == other))
end
round "kernel!="
module Kernel
  remove_method :!=
end

class BasicObject
  alias_method :__zne1_eq, :==
  def ==(other) = (LOG << :basic_eq; __zne1_eq(other))
end
round "basicobject=="
class BasicObject
  alias_method :==, :__zne1_eq
end

class Plain
  private def !=(other) = :private_now
end
round "private!="

class Other
  undef_method :!=
end
round "undef!="

class TrueClass
  def !(*) = :not_overridden
end
class FalseClass
  def !(*) = :not_overridden
end
round "not-overridden"
traced "final"
