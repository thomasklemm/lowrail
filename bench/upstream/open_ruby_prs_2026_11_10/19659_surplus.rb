# ruby --zjit surplus.rb SURPLUS N [LEAD]
# yield LEAD+SURPLUS positional args into a block with LEAD params.
s, n, lead = Integer(ARGV[0]), Integer(ARGV[1]), Integer(ARGV[2] || 1)
argv = (1..lead + s).map { "x" }.join(", ")
params = lead.zero? ? "" : "|" + (1..lead).map { "p#{_1}" }.join(", ") + "|"
body = lead.zero? ? "1" : (1..lead).map { "p#{_1}" }.join(" + ")
eval <<~RUBY
  def y(x) = yield(#{argv})
  def call_once(x) = y(x) { #{params} #{body} }
  def run(n) = (i = 0; r = nil; (r = call_once(i); i += 1) while i < n; r)
RUBY
run(5000)
z = defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
K = %i[compiled_iseq_count compiled_side_exit_count invalidation_time_ns compile_error_out_of_memory]
st = -> { z ? RubyVM::ZJIT.stats.slice(*K) : {} }
GC.start; GC.disable
a = st.()
t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
r = run(n)
t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
b = st.()
extra = z ? RubyVM::ZJIT.stats.values_at(:send_fallback_invokeblock_not_specialized, :block_iseq_direct_optimized_send_count).inspect : ""
warn "s=#{s} lead=#{lead} result=#{r} flat=#{a == b} ns=#{(t * 1e9 / [n, 1].max).round(2)} #{extra}"
