# ruby --yjit sup.rb MODE N [K]
mode, n, k = ARGV[0], Integer(ARGV[1]), Integer(ARGV[2] || 1)
class Parent; def self.foo(x) = x + 1; end
class Child < Parent; def self.foo(x) = super(x) + 1; end
SUBS = Array.new(k) { Class.new(Child) }
module Base; def foo(x) = x + 1; end
module Copied; include Base; extend Base; def foo(x) = super(x) + 1; module_function :foo; end
def cls(i) = SUBS[i % SUBS.size].foo(i)
def mod(i) = Copied.foo(i)
def run(m, n) = (i = 0; (m == "cls" ? cls(i) : mod(i); i += 1) while i < n)
if mode == "retain"
  # N anonymous classes, each with its own class method calling super
  before = ObjectSpace.count_objects[:T_CLASS]
  n.times { |i| c = Class.new(Parent) { def self.foo(x) = super(x) + 2 }; c.foo(i) }
  4.times { GC.start }
  warn "retained_classes=#{ObjectSpace.count_objects[:T_CLASS] - before}"
  exit
end
run(mode, 3000)
K = %i[compiled_iseq_count compiled_block_count invalidation_count]
GC.start; GC.disable
a = RubyVM::YJIT.runtime_stats.slice(*K)
t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
run(mode, n)
t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
b = RubyVM::YJIT.runtime_stats.slice(*K)
warn "flat=#{a == b} ns_per_call=#{(t * 1e9 / [n, 1].max).round(1)} code=#{RubyVM::YJIT.runtime_stats.values_at(:inline_code_size, :outlined_code_size)}"
