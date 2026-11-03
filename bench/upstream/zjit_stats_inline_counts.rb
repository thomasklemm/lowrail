# IncrCounter double-count check (Shopify/ruby#995): fallback counters per call through a 4-deep inline chain.
# ruby --zjit --zjit-stats-quiet --zjit-inline-threshold={0,30} bench/upstream/zjit_stats_inline_counts.rb
class P
  attr_reader :v
  def initialize(x) = (@e = 1 if x; @v = 1)
end
PS = [P.new(false), P.new(true)]
def kw(**k) = k
def c3(p) = (kw; p.v)
def c2(p) = c3(p)
def c1(p) = c2(p)
def top(p) = c1(p)
def run(n) = n.times { |i| top(PS[i % 2]) }
run(2000)
RubyVM::ZJIT.reset_stats!
N = 100_000
run(N)
s = RubyVM::ZJIT.stats
keys = s.keys.select { |k| k.to_s =~ /getivar_fallback|complex_arg_pass_param_kwrest|send_direct_fallback|inline_iseq_optimized|polymorphic/ && s[k].is_a?(Integer) && s[k] > 0 }
keys.each { |k| printf "%-50s %10d  %.2f/call\n", k, s[k], s[k].fdiv(N) }
