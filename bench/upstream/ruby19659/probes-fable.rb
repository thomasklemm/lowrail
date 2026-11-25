# Second differential probe set for RUBY19659 (thermos-fable, head 2f73e7b80a): exits before and inside the
# direct call, where the planned snapshot (block's args only) and the yield's original snapshot differ.
# Output must be identical in the interpreter and under ZJIT at any threshold, with and without inlining.
out = []
probe = lambda do |name, runs = 6, &b|
  r = runs.times.map do
    b.call
  rescue Exception => e # rubocop:disable Lint/RescueException
    "#{e.class}: #{e.message[0, 60]}"
  end
  out << "#{name}: #{r.uniq.map(&:inspect).join(' | ')}"
end

def y2(a, b) = yield(a, b)
def y3(a, b, c) = yield(a, b, c)
def below(a, b) = [:low, yield(a, b), :high]
def below2(a, b) = [a, [b, yield(a + 1, b + 1, a + b)]]

# Guard miss before the call: the interpreter must re-run the yield with every arg.
def train_then_other(n)
  blk = n < 4 ? proc { |a| [:one, a] } : proc { |a, b| [:two, a, b] }
  y2(n, n * 10, &blk)
end
i = 0
probe.("iseq guard miss keeps surplus", 8) { train_then_other(i += 1) }

def mono(n) = n < 5 ? y2(n, -n) { |a| a } : y2(n, -n) { |a, b| [a, b] }
j = 0
probe.("second block after monomorphic", 9) { mono(j += 1) }

def kinds(k)
  case k % 4
  when 0 then y3(1, 2, 3) { :none }
  when 1 then y3(1, 2, 3) { |a| a }
  when 2 then y3(1, 2, 3) { |a, b| [a, b] }
  else y3(1, 2, 3, &:itself)
  end
rescue ArgumentError => e
  e.message
end
k = 0
probe.("polymorphic 0/1/2 params and Symbol", 16) { kinds(k += 1) }

# Exits inside the block: the caller's saved SP is below all yielded args.
probe.("block side exit, live values below") { [below(1, 2) { |a| a + 1 }, below(1.5, 2) { |a| a + 1 }] }
probe.("block side exit, no params") { x = 1; r = below(7, 8) { x + 1 }; x = 1.5; [r, below(7, 8) { x + 1 }] }
probe.("nested live stack") { [below2(1, 2) { |a| a * 2 }, below2(1.5, 2) { |a| a * 2 }] }
probe.("block raises") { below(1, 2) { |a| raise "boom #{a}" } }
probe.("block raises, caller rescues") do
  def rescuing(a, b) = [yield(a, b), :ok]
  def rescuing2(a, b) = (begin; rescuing(a, b) { |x| Integer(x) }; rescue ArgumentError => e; [e.class, b]; end)
  [rescuing2("1", :s), rescuing2("x", :s)]
end
probe.("ensure in yielder") do
  log = []
  def ens(log, a, b) = (begin; yield(a, b); ensure; log << [:ensure, a, b]; end)
  [ens(log, 1, 2) { |x| x + 1 }, (ens(log, :s, 2) { |x| x + 1 } rescue :err), log]
end
probe.("next and break values") do
  [y2(1, 2) { |a| next a + 10 }, y2(1, 2) { |a| break a + 20 }, y3(1, 2, 3) { next :n }]
end
probe.("non-local return from block") { (def nlr = (y2(1, 2) { |a| return a + 30 }; :no)); nlr }

# The block's frame overlays the dropped slots: its own locals and EP must be intact.
probe.("block locals nil-initialised") { y3(:a, :b, :c) { |a| t = u = nil; v = defined?(w) ? w : :unset; [a, t, u, v] } }
probe.("block-local var list") { z = :outer; [y3(1, 2, 3) { |a; z| z = a; z }, z] }
probe.("binding in block") { y3(1, 2, 3) { |a| b = a + 1; binding.local_variables.first(2) + [binding.local_variable_get(:a), b] } }
probe.("closure write") { n = 0; 3.times { n += 10 }; y3(1, 2, 3) { n += 1 }; n }
probe.("block calls a method with args") { def add3(a, b, c) = a + b + c; y3(1, 2, 3) { |a| add3(a, a, a) } }
probe.("block yields onward with surplus") { def outer2 = y3(1, 2, 3) { |a| yield(a, a + 1, a + 2) }; outer2 { |p, q| [p, q] } }
probe.("proc from block") { y2(1, 2) { |a| pr = proc { |x, y| [x, y] }; pr.call(a, 9, 9) } }
probe.("GC in block") { y3("s" * 3, "t" * 3, "u" * 3) { |a| GC.start; a + a } }
probe.("GC.stress") do
  GC.stress = true
  r = y3([1], [2], [3]) { |a| a + [a.size] }
  GC.stress = false
  r
ensure
  GC.stress = false
end
probe.("surplus arg objects stay usable") { s = +"keep"; y2(1, s) { |a| a }; s << "!"; s }

# Exit before the call from the stack overflow check: must re-run the yield with every arg.
def deep(n, m, &blk) = y2(n, m) { |a| a.zero? ? :bottom : deep(a - 1, m, &blk) }
probe.("deep recursion returns") { deep(300, :m) }
def runaway(n, m) = y2(n, m) { |a| runaway(a + 1, m) }
probe.("SystemStackError", 3) { runaway(0, :m) }
probe.("after overflow") { [y2(1, 2) { |a| a }, y3(1, 2, 3) { |a, b| [a, b] }] }

# Many args: more than fit in argument registers, with and without surplus.
def many = yield(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
probe.("10 args into 0/1/8/10 params") do
  [many { :none }, many { |a| a }, many { |a, b, c, d, e, f, g, h| [a, h] },
   many { |a, b, c, d, e, f, g, h, i, j| [a, j] }]
end

# Library yields that pass more than the block takes.
probe.("each_with_index, no params") { c = 0; [5, 6].each_with_index { c += 1 }; c }
probe.("each_with_index |x|") { [5, 6].each_with_index.map { |x| x } }
probe.("Hash#each |k|") { r = []; { a: 1, b: 2 }.each { |k| r << k }; r }
probe.("Hash#each no params") { c = 0; { a: 1, b: 2 }.each { c += 1 }; c }
probe.("times/upto/step no params") { c = 0; 3.times { c += 1 }; 1.upto(3) { c += 1 }; 1.step(5, 2) { c += 1 }; c }
probe.("Fiber around a surplus yield") { Fiber.new { y3(1, 2, 3) { |a| Fiber.yield(a); :done } }.then { |f| [f.resume, f.resume] } }

# One yielder per call site, so the profile stays monomorphic and the call is direct without inlining too.
def own_exit(a, b) = [:low, yield(a, b), :high]
probe.("own yielder: block side exit") { [own_exit(1, 2) { |a| a + 1 }, own_exit(1, 2) { |a| a + 1 }] }
def own_exit_f(a, b) = [:low, yield(a, b), :high]
def own_exit_f_call(x) = own_exit_f(x, 2) { |a| a + 1 }
f = 0
probe.("own yielder: Float after Fixnums", 8) { own_exit_f_call((f += 1) < 6 ? f : f + 0.5) }
def own_deep(n, m) = yield(n, m)
def own_runaway(n, m) = own_deep(n, m) { |a| own_runaway(a + 1, m) }
probe.("own yielder: SystemStackError", 3) { own_runaway(0, :m) }
def own_raise(a, b) = [yield(a, b), :ok]
def own_raise_call(s) = (begin; own_raise(s, :dropped) { |x| Integer(x) }; rescue ArgumentError; :rescued; end)
r = 0
probe.("own yielder: raise after ints", 8) { own_raise_call((r += 1) < 6 ? r.to_s : "x") }
def own_none(a, b, c) = [a, yield(a, b, c), c]
def own_none_call(v) = own_none(v, :b, :c) { v.succ }
probe.("own yielder: no params, exit on String", 8) { own_none_call((r += 1) < 14 ? r : "a") }
def own_two(a, b, c, d) = yield(a, b, c, d)
def own_two_call(v) = own_two(v, v + 1, :c, :d) { |a, b| a * b }
probe.("own yielder: 4 args into |a, b|") { [own_two_call(3), own_two_call(2.5)] }

puts out
if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? && RubyVM::ZJIT.respond_to?(:stats)
  stats = RubyVM::ZJIT.stats
  warn "direct=#{stats[:block_iseq_direct_optimized_send_count].inspect} invokeblock_not_specialized=#{stats[:send_fallback_invokeblock_not_specialized].inspect}"
end
