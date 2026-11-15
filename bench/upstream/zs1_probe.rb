# Differential probe for block arguments (`&:sym`, `&blk`, `&proc`) under ZJIT, for docs/upstream/zjit-symbol-block.md.
#   ruby zs1_probe.rb > interp.txt; ruby --zjit --zjit-call-threshold=1 zs1_probe.rb > zjit.txt; diff interp.txt zjit.txt
# Every case runs N times at one call site (N above the call threshold), then with changed inputs. A line holds the
# value or the exception class and message. PROBE_STATS=1 prints the block-argument counters to stderr.
N = Integer(ENV.fetch("N", "6"))

def show(name, i)
  r = begin
    yield.inspect
  rescue Exception => e # rubocop:disable Lint/RescueException
    "#{e.class}: #{e.message.lines.first&.chomp}"
  end
  puts "#{name}[#{i}] #{r}"
end

def run(name, n = N) = n.times { |i| show(name, i) { yield i } }

class K
  def initialize(v) = @v = v
  def inspect = "K(#{@v})"
  def pub = @v
  def two(a, b = :dflt) = [@v, a, b]
  def kw(a = nil, k: 1) = [@v, a, k]
  def boom = raise(ArgumentError, "boom #{@v}")
  def where = caller_locations(0, 4).map { [_1.base_label, _1.lineno] }
  def trace = caller(0, 4).map { _1[/[^\/]+\z/] }
  def rec = one(self, &:rec)
  def down = (@v -= 1) > 0 ? one(self, &:down) + 1 : 0
  def call_prot(o) = one(o, &:prot)
  def call_priv = one(self, &:priv)
  def method_missing(m, *a) = m.to_s.start_with?("mm_") ? [:mm, m, a] : super
  def respond_to_missing?(m, p = false) = m.to_s.start_with?("mm_") || super
  private def priv = :priv
  protected def prot = :prot
end

class ToProc
  def initialize(v) = @v = v
  def to_proc = @v
end

def one(x) = yield(x)
def zero = yield
def many(a, b, c) = yield(a, b, c)
def splat(*a) = yield(*a)
def kws(x, **k) = yield(x, **k)
def opt(x, y = 2, k: 3) = [yield(x), y, k]
def given = block_given?
def noblk(x) = x
def nilblk(x, &nil) = x
def mat(&b) = [b.class, b.lambda?, b.arity, b.parameters]
def ident(&b) = b
def mat_call(x, &b) = b.call(x)
def fwd(x, &b) = one(x, &b)
def fwd2(x, &b) = fwd(x, &b)
def fwd_c(a, &b) = a.map(&b)
def fwd_each(a, &b) = a.each(&b)
def anon(x, &) = one(x, &)
def dots(...) = one(...)
def reb(x, &b)
  b = :pub.to_proc if x
  one(K.new(1), &b)
end
def setnil(&b)
  b = nil
  given(&b)
end
def read_then_fwd(x, &b)
  b.arity
  one(x, &b)
end
class Sup
  def m(x) = yield(x)
end
class Sub < Sup
  def m(x) = super(x, &:pub)
  def z(x) = super
end
Object.define_method(:bm) { |x, &b| b ? b.call(x) : :none }

def t_lit(x) = one(x, &:pub)
def t_var(x, s) = one(x, &s)
def t_zero = zero(&:pub)
def t_many = many(K.new(1), 2, 3, &:two)
def t_splat(a) = splat(*a, &:two)
def t_kw = kws(K.new(1), k: 5, &:kw)
def t_opt = opt(K.new(1), k: 9, &:pub)
def t_priv = one(K.new(1), &:priv)
def t_prot = one(K.new(1), &:prot)
def t_mm = one(K.new(1), &:mm_x)
def t_nomm = one(K.new(1), &:nope)
def t_given = given(&:pub)
def t_noblk = noblk(1, &:pub)
def t_nilblk = nilblk(1, &:pub)
def t_mat = mat(&:pub)
def t_ident = ident(&:pub).equal?(ident(&:pub))
def t_mat_call(x) = mat_call(x, &:pub)
def t_fwd(x) = fwd(x, &:pub)
def t_fwd2(x) = fwd2(x, &:pub)
def t_fwd_lit(x) = fwd2(x) { |k| k.pub + 1 }
def t_fwd_none(x) = fwd2(x)
def t_fwd_var(x, s) = fwd2(x, &s)
def t_anon(x) = anon(x, &:pub)
def t_dots(x) = dots(x, &:pub)
def t_bm(x) = bm(x, &:pub)
def t_send(x) = send(:one, x, &:pub)
def t_psend(x) = public_send(:then, &:pub) rescue :err
def t_safe(x) = x&.then(&:pub)
def t_basic = one(BasicObject.new, &:!)
def t_basic_nome = one(BasicObject.new, &:inspect)
def t_frozen = one("x".freeze, &:upcase!)
def t_op = many(1, 2, 3, &:+) rescue $!.class
def t_boom(x) = one(x, &:boom)
def t_where(x) = one(x, &:where)
def t_trace(x) = one(x, &:trace)
def t_break(x) = fwd2(x) { break 5 }
def t_next(x) = fwd2(x) { next 6 }
def t_ret(x)
  fwd2(x) { return 7 }
  0
end
def t_lambda(x) = fwd2(x, &->(k) { return k.pub * 2 })
def t_lambda_arity = many(1, 2, 3, &->(k) { k })
def t_map(a) = a.map(&:pub)
def t_each(a) = a.each(&:pub)
def t_select(a) = a.select(&:pub)
def t_reject(a) = a.reject(&:pub)
def t_any(a) = a.any?(&:pub)
def t_uniq(a) = a.uniq(&:pub)
def t_flat(a) = a.flat_map(&:two) rescue $!.class
def t_sort(a) = a.sort_by(&:pub)
def t_inject(a) = a.inject(&:+)
def t_tv(h) = h.transform_values(&:pub)
def t_times = 3.times.map(&:succ)
def t_tap(x) = x.tap(&:pub)
def t_then(x) = x.then(&:pub)
def t_cvar(a, s) = a.reject(&s)
def t_cmap_var(a, s) = a.map(&s)
def t_cnone(a) = a.reject(&nil)

k1 = K.new(1)
ks = [K.new(1), K.new(nil), K.new(1), K.new(false)]

run("lit") { t_lit(k1) }
run("lit_recv") { |i| t_lit(i.even? ? k1 : "str") }
vars = [:pub] * N + [:two, :nope, :priv, "dyn_pub_#{$$ % 1}".to_sym, "mm_dyn#{N}".to_sym, :pub.to_proc, proc { |k| [:proc, k] },
        ->(k) { [:lambda, k] }, nil, k1.method(:two), ToProc.new(proc { |k| [:tp, k] }), ToProc.new(:pub), ToProc.new(nil),
        Object.new, 42, :pub, "pub", :mm_y]
vars.each_with_index { |s, i| show("var", i) { t_var(k1, s) } }
vars.reverse.each_with_index { |s, i| show("cvar", i) { t_cvar(ks, s) } }
vars.each_with_index { |s, i| show("cmap_var", i) { t_cmap_var(ks, s) } }
vars.each_with_index { |s, i| show("fwd_var", i) { t_fwd_var(k1, s) } }
run("zero") { t_zero }
run("many") { t_many }
run("splat") { |i| t_splat(i < N - 2 ? [k1, 2] : i < N - 1 ? [k1] : []) }
run("kw") { t_kw }
run("opt") { t_opt }
run("priv") { t_priv }
run("call_priv") { k1.call_priv }
run("prot") { t_prot }
run("call_prot") { k1.call_prot(K.new(2)) }
run("mm") { t_mm }
run("nomm") { t_nomm }
run("given") { t_given }
run("noblk") { t_noblk }
run("nilblk") { t_nilblk }
run("mat") { t_mat }
run("ident") { t_ident }
run("mat_call") { t_mat_call(k1) }
run("fwd") { t_fwd(k1) }
run("fwd2") { t_fwd2(k1) }
run("fwd_lit") { t_fwd_lit(k1) }
run("fwd_none") { t_fwd_none(k1) }
run("fwd_mixed") { |i| i.even? ? t_fwd_lit(k1) : t_fwd2(k1) }
run("fwd_c") { |i| i.even? ? fwd_c(ks, &:pub) : fwd_c(ks) { _1.pub.inspect } }
run("fwd_c_none") { fwd_c(ks).class }
run("fwd_each") { |i| i < N - 1 ? fwd_each(ks, &:pub) : fwd_each(ks).class }
run("anon") { t_anon(k1) }
run("dots") { t_dots(k1) }
run("reb") { |i| reb(i.even?) { |k| [:orig, k] } }
run("setnil") { setnil { 1 } }
run("read_then_fwd") { |i| i.even? ? read_then_fwd(k1, &:pub) : read_then_fwd(k1) { |k| k.pub.to_s } }
run("super") { Sub.new.m(k1) }
run("zsuper") { Sub.new.z(k1, &:pub) }
run("bm") { t_bm(k1) }
run("send") { t_send(k1) }
run("psend") { t_psend(k1) }
run("safe") { |i| t_safe(i.even? ? k1 : nil) }
run("basic") { t_basic }
run("basic_nome") { t_basic_nome }
run("frozen") { t_frozen }
run("op") { t_op }
run("boom") { t_boom(k1) }
run("boom_bt") { t_boom(k1) rescue $!.backtrace_locations.first(5).map { [_1.base_label, _1.lineno] } }
run("where") { t_where(k1) }
run("trace") { t_trace(k1) }
run("break") { t_break(k1) }
run("next") { t_next(k1) }
run("ret") { t_ret(k1) }
run("lambda") { t_lambda(k1) }
run("lambda_arity") { t_lambda_arity }
run("map") { t_map(ks) }
run("each") { t_each(ks) }
run("select") { t_select(ks) }
run("reject") { t_reject(ks) }
run("any") { |i| t_any(i.even? ? ks : []) }
run("uniq") { t_uniq(ks) }
run("flat") { t_flat(ks) }
run("sort") { t_sort([K.new(3), K.new(1), K.new(2)]) }
run("inject") { |i| t_inject(i < N - 1 ? [1, 2, 3] : ["a", "b"]) }
run("tv") { t_tv({a: k1, b: K.new(2)}) }
run("times") { t_times }
run("tap") { t_tap(k1) }
run("then") { t_then(k1) }
run("cnone") { t_cnone(ks).class }
run("map_poly") { |i| t_map(i.even? ? ks : [Struct.new(:pub).new(i)]) }

# Refinements in the caller's cref: the Symbol becomes a lambda that looks the method up with the refinements.
module Ref
  refine(K) do
    def pub = [:refined, super]
    def only_ref = :only_ref
  end
end
module RefUser
  using Ref
  def self.lit(x) = one(x, &:pub)
  def self.only(x) = one(x, &:only_ref)
  def self.var(x, s) = one(x, &s)
  def self.creject(a) = a.reject(&:only_ref)
  def self.cmap(a) = a.map(&:pub)
  def self.rmat = mat(&:pub)
  def self.rfwd(x) = fwd2(x, &:only_ref)
  def self.rzero = zero(&:pub)
  def self.rident = ident(&:pub).equal?(ident(&:pub))
end
run("ref_lit") { RefUser.lit(k1) }
run("ref_only") { RefUser.only(k1) }
run("ref_unrefined_site") { t_var(k1, :only_ref) }
run("ref_var") { |i| RefUser.var(k1, i.even? ? :pub : :only_ref) }
run("ref_creject") { RefUser.creject(ks) }
run("ref_cmap") { RefUser.cmap(ks) }
run("ref_mat") { RefUser.rmat }
run("ref_fwd") { RefUser.rfwd(k1) }
run("ref_zero") { RefUser.rzero }
run("ref_ident") { RefUser.rident }
run("ref_then_plain") { |i| i.even? ? RefUser.lit(k1) : t_lit(k1) }

# Dynamic Symbols and GC: nothing the compiled code holds may be collected or moved from under it.
run("dyn") { |i| t_var(k1, "mm_gc_#{i}_#{rand(1 << 30).to_s(36)}".to_sym).first(1) }
GC.stress = true
run("gc_stress", 3) { |i| [t_lit(k1), t_var(k1, "mm_s#{i}".to_sym), RefUser.only(k1), t_reject(ks), t_fwd2(k1), RefUser.creject(ks)] }
GC.stress = false
GC.compact if GC.respond_to?(:compact)
run("after_compact", 2) { [t_lit(k1), t_map(ks), RefUser.lit(k1), t_fwd_lit(k1)] }

# Deep recursion through the send, then a stack overflow inside it.
run("down", 3) { K.new(3000).down }
show("deep", 0) { k1.rec } if ENV["PROBE_DEEP"] != "0"
run("after_deep", 2) { t_lit(k1) }

# Symbol#to_proc redefined: after warmup, and during the conversion itself.
def redef_target = yield(:old)
def t_redef = redef_target(&:to_s)
run("redef_before") { [t_redef, t_lit(k1), t_reject(ks), t_fwd2(k1)] }
class Symbol
  alias_method :zs1_to_proc, :to_proc
  def to_proc
    $to_proc_calls += 1
    Object.send(:define_method, :redef_target) { |&b| b.call(:new) } if $swap
    sym = self
    proc { |x| [:redefined, sym, x] }
  end
end
$to_proc_calls = 0
$swap = true
run("redef_during", 3) { t_redef }
$swap = false
run("redef_after") { [t_lit(k1), t_var(k1, :pub), t_reject(ks.first(2)), t_fwd2(k1), t_mat, t_given, RefUser.lit(k1), $to_proc_calls] }
class Symbol
  alias_method :to_proc, :zs1_to_proc
end
run("redef_restored") { [t_lit(k1), t_var(k1, :pub), t_reject(ks), t_fwd2(k1), t_mat, RefUser.lit(k1), $to_proc_calls] }

# TracePoint: the same events in the same order, on warm call sites. Late, because ZJIT side-exits from ISEQs
# compiled after a TracePoint was first enabled.
def traced
  events = []
  tp = TracePoint.new(:call, :return, :c_call, :c_return, :b_call, :b_return) do |t|
    events << [t.event, t.method_id] unless %i[enable disable].include?(t.method_id) || t.path != __FILE__ && t.event.start_with?("b")
  end
  tp.enable
  yield
  tp.disable
  events
end
run("tp_iseq", 3) { traced { t_lit(k1) } }
run("tp_c", 3) { traced { t_reject(ks.first(2)) } }
run("tp_fwd", 3) { traced { t_fwd_lit(k1) } }
run("tp_after", 3) { [t_lit(k1), t_reject(ks), t_fwd_lit(k1)] }

# Ractors: a Symbol handler and a refined one built on another Ractor. Last, because ZJIT compiles no new code
# once a second Ractor has started.
if defined?(Ractor) && ENV["PROBE_RACTOR"] != "0"
  Warning[:experimental] = false
  join = Ractor.instance_method(Ractor.method_defined?(:value) ? :value : :take)
  run("ractor", 2) do
    r = Ractor.new { k = K.new(2); [50.times.sum { t_lit(k) }, t_reject([k]), RefUser.only(k), t_fwd2(k), RefUser.creject([k])] }
    join.bind_call(r)
  end
  run("ractor_after", 2) { [t_lit(k1), RefUser.only(k1)] }
end

if ENV["PROBE_STATS"] == "1" && defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
  stats = RubyVM::ZJIT.stats
  keys = stats.keys.grep(/blockarg|block_arg|symbol_block|invokeblock_not_spec|compiled_iseq_count|^side_exit_count|unhandled_block/i)
  warn keys.to_h { [_1, stats[_1]] }.select { _2 != 0 }.inspect
end
