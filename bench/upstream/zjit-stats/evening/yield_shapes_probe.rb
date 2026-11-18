# Which block shapes still take the generic invokeblock path once Array#each/find/map are force-inlined?
# ruby --zjit --zjit-stats-quiet yield_shapes_probe.rb CASE
A = [[1, 2], [3, 4], [5, 6]]
S = %w[a b c]
H = [[Integer, :i], [String, :s]]
def simple(a) = (s = 0; a.each { |(x, y)| s += x }; s)
def plain(a) = (s = 0; a.each { |x| s += x[0] }; s)
def brk(a) = (a.each { |x| break x if x[0] == 3 })
def splat2(a) = (a.find { |k, _| k == 3 })
def sym(a) = a.each(&:-@)
def fwd(a, &b) = a.each(&b)
def ret(a) = (a.each { |x| return x if x[0] == 5 }; nil)
CASES = {
  "plain" => -> { plain(A) }, "destructure" => -> { simple(A) }, "break" => -> { brk(A) },
  "find_autosplat" => -> { splat2(A) }, "symbol_blockarg" => -> { sym(S) },
  "forward_blockarg" => -> { fwd(A) { |x| x } }, "return" => -> { ret(A) },
}
# make Array#each/find polymorphic out of line
20.times { |i| [1].each { |x| x + i }; [2].each { |x| x.to_s }; [3].find { |x| x == 3 } }
c = CASES.fetch(ARGV[0])
2000.times { c.() }
RubyVM::ZJIT.reset_stats!
10000.times { c.() }
s = RubyVM::ZJIT.stats
puts [ARGV[0], *%w[send_fallback_invokeblock_polymorphic_miss send_fallback_invokeblock_not_specialized send_fallback_send_block_arg_not_nil block_iseq_direct_optimized_send_count dynamic_send_count side_exit_count].map { "#{_1.sub(/send_fallback_|_optimized_send_count/, "")}=#{s[_1.to_sym]}" }].join(" ")
