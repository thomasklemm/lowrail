# frozen_string_literal: true

# Callgrind instructions per operation for chosen census workloads (run from the copy's directory under
# valgrind --tool=callgrind --instr-atstart=no, with -I the lowrail_callgrind extension).
# Per workload: WARM ops, GC.start, GC off, an empty window (dump), then N ops (dump). JIT counters are read
# around the N window; one JSON line with the counters, objects per op and the dump order.
require "json"
require "lowrail_callgrind"
require File.expand_path("~/workspace/repo/bench/upstream/census/harness.rb")

app = ENV.fetch("APP")
RailsCensus.boot(app)
ops = RailsCensus.workloads(app)
only = ENV.fetch("ONLY").split("|")
ops = only.map { |name| ops.find { _1.name == name } or raise "no workload #{name}" }
run = ->(op) { op.call.call; RailsCensus.reset_side_effects }
warm = Integer(ENV.fetch("WARM", "200"))
n = Integer(ENV.fetch("N", "20"))
counters = lambda do
  if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    RubyVM::ZJIT.stats.slice(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns)
  elsif RubyVM::YJIT.enabled?
    RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count)
  else
    {}
  end
end
ops.each { |op| warm.times { run.(op) } }
results = ops.map do |op|
  3.times { run.(op) }
  3.times { GC.start }
  GC.disable
  LowrailCallgrindBench.start(false)
  LowrailCallgrindBench.finish
  before = counters.call
  objs = GC.stat(:total_allocated_objects)
  LowrailCallgrindBench.start(false)
  n.times { run.(op) }
  LowrailCallgrindBench.finish
  objs = (GC.stat(:total_allocated_objects) - objs).fdiv(n)
  after = counters.call
  GC.enable
  { workload: op.name, n: n, objects: objs.round(1), jit_flat: before == after, before: before, after: after }
end
puts JSON.generate(arm: ENV.fetch("ARM"), app: app, ruby: RUBY_DESCRIPTION, results: results)
