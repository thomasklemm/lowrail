# Per-call cost of Kernel#send under ZJIT versus a direct call.
# ruby --zjit bench/upstream/zjit_send_micro.rb
class Node
  def initialize = @v = 1
  def visit_a(x, y) = x
  def visit_b(x, y) = x
  def visit_c(x, y) = x
  def visit_d(x, y) = x
end

N = Integer(ENV.fetch("N", 20_000_000))
NAMES = %i[visit_a visit_b visit_c visit_d].freeze

def direct(o, n)      = (i = 0; while i < n; o.visit_a(i, nil); i += 1; end)
def static_send(o, n) = (i = 0; while i < n; o.send(:visit_a, i, nil); i += 1; end)
def dyn_mono(o, n)    = (m = NAMES[0]; i = 0; while i < n; o.send(m, i, nil); i += 1; end)
def dyn_poly(o, n)    = (i = 0; while i < n; o.send(NAMES[i & 3], i, nil); i += 1; end)
def poly_direct(o, n) = (i = 0; while i < n; case i & 3 when 0 then o.visit_a(i, nil) when 1 then o.visit_b(i, nil) when 2 then o.visit_c(i, nil) else o.visit_d(i, nil) end; i += 1; end)

o = Node.new
%i[direct static_send dyn_mono dyn_poly poly_direct].each do |m|
  100.times { send(m, o, 1_000) } # past the JIT call threshold
  best = 5.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    send(m, o, N)
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
  end.min
  printf("%-12s %6.2f ns/call\n", m, best * 1e9 / N)
end
