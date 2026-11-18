# Probes for ZJIT changes between 90dbced795 and 7919a47d46. Prints one line per check; compare the output across modes.
$out = []
def chk(name) = $out << "#{name}: #{(yield).inspect rescue "#{$!.class}: #{$!.message}"}"

# Locals in stack maps (side exits read locals from the stack map instead of spilled slots).
def locals_exit(a, b)
  x = a + 1
  y = b.to_s
  z = [x, y]
  w = a.is_a?(Integer) ? x * 2 : x
  [x, y, z, w, binding.local_variable_get(:x)]
end
def locals_after_call(n)
  acc = 0
  i = 0
  while i < n
    v = i
    acc += yield(v)
    i += 1
  end
  [acc, i, v]
end
def locals_eval(a)
  b = a * 2
  eval("b += 1")
  [a, b]
end
def locals_block_mut
  t = 1
  [1, 2].each { t += _1 }
  u = t
  [t, u]
end

# GetBlockParam in an inlined callee whose env escapes.
def gbp(&blk) = blk
def gbp_escape(&blk)
  b = blk
  -> { b }
end
def gbp_caller
  r = gbp { 42 }
  l = gbp_escape { 7 }
  [r&.call, l.call.call]
end

# Polymorphic class + monomorphic shape getivar.
class PA; def initialize; @a = 1; @b = 2; end; def b = @b; end
class PB; def initialize; @a = 3; @b = 4; end; def b = @b; end
class PC < PA; def initialize; super; @c = 5; end; end
def poly_ivar(o) = o.instance_variable_get(:@b)
def poly_read(o) = o.b
o_s = PA.new; def o_s.b = @b * 10
class PA; attr_reader :a; end
def ivar_reader(o) = o.a

# opt_neq polymorphic.
class NeqA; def ==(o) = true; end
class NeqB; def !=(o) = :custom; end
class NeqC; def ==(o) = o == 3; end
def neq(a, b) = (a != b)

# Hash literal with String keys (gen_new_hash).
def hstr(v) = { "a" => v, "b" => v.to_s }
def hstr_mut(s) = { s => 1 }

# expandarray with nil.
def ea(v) = (a, b = v; [a, b])

# Integer#== true/false and Float#== nil/true/false folds.
def ieq(a, b) = (a == b)

# super with a block from a method that received one.
class SupA; def m(*) = block_given? ? yield : :noblk; end
class SupB < SupA; def m(x, &) = super; end
class SupC < SupA; def m(x) = super(x); end

# Interpolation of Integer and Module without to_s.
module IM; end
def interp(v) = "<#{v}>"

# Integer#pred, anybits?, IO::Buffer#get_value, String.new(capacity:).
def ipred(i) = i.pred
def anyb(a, b) = a.anybits?(b)
def iobuf(b, t, o) = b.get_value(t, o)
def snew(c) = String.new(capacity: c).then { [_1.encoding, _1.size] }

# opt_new refinements (Bug #22539).
class RNew; def initialize = (@x = :orig); attr_reader :x; end
module RNewRef; refine RNew do; def initialize = (@x = :refined); end; end
using RNewRef
def rnew = RNew.new.x

# Symbol block args and Proc block args to &b callees.
def sym_blk(a) = a.map(&:to_s)
def take_blk(&b) = b
def sym_to_blk = take_blk(&:upcase).call("x")

20.times do |round|
  $out.clear
  chk(:locals_exit) { locals_exit(round, round.odd? ? :s : 1.5) }
  chk(:locals_exit_str) { locals_exit(round.odd? ? 1.5 : round, :t) }
  chk(:locals_after_call) { locals_after_call(round % 4) { |v| round > 10 ? v.to_f : v } }
  chk(:locals_eval) { locals_eval(round) }
  chk(:locals_block_mut) { locals_block_mut }
  chk(:gbp) { gbp_caller }
  objs = [PA.new, PB.new, PC.new, o_s]
  chk(:poly_ivar) { objs.map { poly_ivar(_1) } }
  chk(:poly_read) { objs.map { poly_read(_1) } }
  chk(:ivar_reader) { objs.map { ivar_reader(_1) rescue $!.class } }
  chk(:neq) { [neq(1, 2), neq(1, 1), neq(NeqA.new, 1), neq(NeqB.new, 1), neq(NeqC.new, 3), neq("a", "a"), neq(:a, :b), neq(nil, false), neq(1.0, 1)] }
  chk(:hstr) { [hstr(round), hstr(nil)] }
  s = +"k#{round}"; h = hstr_mut(s); s << "x"
  chk(:hstr_mut) { [h, h.keys.first.frozen?] }
  chk(:ea) { [ea(nil), ea([1, 2]), ea(round), ea([round])] }
  chk(:ieq) { [ieq(1, true), ieq(1, false), ieq(1.0, nil), ieq(1.0, true), ieq(0, 0.0), ieq(1.0, false), ieq(round, nil)] }
  chk(:sup) { [SupB.new.m(1) { :blk }, SupB.new.m(1), SupC.new.m(1) { :blk2 }] }
  chk(:interp) { [interp(round), interp(IM), interp(Comparable), interp(2**70), interp(-round), interp(Class.new.tap { |c| c.define_singleton_method(:to_s) { "anon" } })] }
  if round == 12
    class Integer; alias_method :orig_to_s, :to_s; def to_s(*a) = "I#{orig_to_s(*a)}"; end
    module IM; def self.to_s = "IMx"; end
  end
  if round == 16
    class Integer; alias_method :to_s, :orig_to_s; end
  end
  chk(:ipred) { [ipred(round), ipred(2**64), (ipred(1.5) rescue $!.class)] }
  chk(:anyb) { [anyb(round, 3), anyb(2**65, 2**65), (anyb(1, 1.5) rescue $!.class)] }
  buf = IO::Buffer.for([0x01020304, 0xfffefdfc].pack("NN"))
  chk(:iobuf) { [:U8, :U16, :u16, :U32, :u32, :U64, :u64].map { iobuf(buf, _1, 0) } + [(iobuf(buf, :U32, 7) rescue $!.class)] }
  chk(:snew) { [snew(round), snew(1000)] }
  chk(:rnew) { rnew }
  chk(:sym_blk) { sym_blk([1, :a, nil]) }
  chk(:sym_to_blk) { sym_to_blk }
  puts "round #{round}", $out if round == 0 || round == 1 || round >= 9
end
