# Differential probes for #18326 (sendforward), #19583 (.send(:sym)), #19483 (protected sends).
# Every case runs from a warm site and then at changed inputs; output must match the interpreter.
$out = []
def rec(tag, &b)
  6.times do |i|
    v = begin
      b.call(i)
    rescue Exception => e
      "#{e.class}: #{e.message[0, 80]}"
    end
    $out << "#{tag}[#{i}] #{v.inspect}"
  end
end

# ---- sendforward (#18326)
class F
  def target(*a, **kw, &blk) = [a, kw, blk&.call]
  def fwd(...) = target(...)
  def fwd7(...) = target(7, ...)
  def fwd2(...) = fwd(...)
  def ytarget(*a) = [a, (block_given? ? yield(a.size) : :noblk)]
  def yfwd(...) = ytarget(...)
end
f = F.new
rec(:fwd_argc) { |i| i < 3 ? f.fwd(1) : [f.fwd(1, 2), f.fwd, f.fwd(3, 4, 5)] }
rec(:fwd7_argc) { |i| i < 3 ? f.fwd7(1) : [f.fwd7, f.fwd7(1, 2)] }
rec(:fwd2_nested) { |i| i < 3 ? f.fwd2(:a) : [f.fwd2, f.fwd2(:a, :b)] }
rec(:fwd_kw) { |i| i < 3 ? f.fwd(1) : f.fwd(1, k: 2) }
rec(:fwd_splat) { |i| a = [1, 2, 3][0, i % 3]; i < 3 ? f.fwd(1) : f.fwd(*a) }
rec(:fwd_blk) { |i| i < 3 ? f.fwd(1) : f.fwd(1) { :b } }
rec(:yfwd) { |i| i.even? ? f.yfwd(1) { _1 * 10 } : f.yfwd(1, 2) }
class G < F; def target(*a) = [:g, a]; end
rec(:fwd_poly_recv) { |i| (i < 3 ? f : G.new).fwd(i) }

# ---- .send(:sym) (#19583)
class S
  def pub(x = 0) = [:pub, x]
  def blk = block_given? ? yield : :none
  def ar(a, b) = [a, b]
  protected def prot = :prot
  private def priv = :priv
  def method_missing(n, *a) = n == :ghost ? [:mm, a] : super
  def respond_to_missing?(n, p = false) = n == :ghost || super
  def via_self = send(:priv)
end
s = S.new
rec(:send_pub) { |i| s.send(:pub, i) }
rec(:send_priv) { s.send(:priv) }
rec(:send_prot) { s.send(:prot) }
rec(:__send__priv) { s.__send__(:priv) }
rec(:send_blk) { |i| i.even? ? s.send(:blk) { :y } : s.send(:blk) }
rec(:send_arity) { |i| i < 3 ? s.send(:ar, 1, 2) : s.send(:ar, 1) }
rec(:send_ghost) { s.send(:ghost, 1) }
rec(:send_dyn) { |i| s.send(i.even? ? :pub : :priv) }
rec(:send_self) { s.via_self }
rec(:send_bt) { |i| i < 3 ? s.send(:pub) : (s.send(:ar) rescue $!.backtrace_locations.first(2).map(&:label)) }
rec(:send_redef) do |i|
  if i == 3
    S.class_eval { def pub(x = 0) = [:pub2, x] }
  end
  if i == 4
    S.class_eval { def send(*) = :redefined_send }
  end
  s.send(:pub, i)
end
S.class_eval { remove_method :send }
rec(:send_remove) do |i|
  S.class_eval { remove_method :ar } if i == 3
  s.send(:ar, 1, 2)
end
class BO < BasicObject; def m = :bo; end
bo = BO.new
rec(:bo___send__) { bo.__send__(:m) }
module Ref; refine(S) { def pub(x = 0) = [:refined, x] }; end
using Ref
rec(:send_refined) { |i| s.send(:pub, i) }
rec(:send_cfunc) { |i| [1, 2, 3].send(:first, i % 3) }
rec(:send_attr) { |i| Struct.new(:a).new(i).send(:a) }
rec(:send_block_given_q) { |i| i.even? ? s.send(:blk) { 1 } : s.send(:blk) }

# ---- protected (#19483)
class P
  def initialize(v) = @v = v
  protected def v = @v
  def cmp(o) = o.v
  def in_block(o) = [1].map { o.v }
  def via_exec(o) = Object.new.instance_exec(o) { |x| x.v rescue $!.class }
end
class P2 < P; end
class Q; def peek(o) = (o.v rescue $!.class); end
module M; protected def mv = :mv; def call_mv(o) = (o.mv rescue $!.class); end
class MA; include M; end
class MB; include M; end
p1 = P.new(1)
rec(:prot_cmp) { |i| p1.cmp(i < 3 ? P.new(i) : P2.new(i)) }
rec(:prot_sub_caller) { |i| P2.new(0).cmp(P.new(i)) }
rec(:prot_block) { |i| p1.in_block(P.new(i)) }
rec(:prot_exec) { |i| p1.via_exec(P.new(i)) }
rec(:prot_other) { Q.new.peek(p1) }
rec(:prot_module) { |i| (i < 3 ? MA.new : MB.new).call_mv(MA.new) }
o = Object.new
def o.try(x) = (x.v rescue $!.class)
rec(:prot_singleton) { o.try(p1) }

puts $out
