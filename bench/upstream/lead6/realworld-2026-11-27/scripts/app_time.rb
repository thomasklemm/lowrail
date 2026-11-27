# frozen_string_literal: true

# Real requests in a census copy (run from the copy's directory):
#   APP_MODE=time    one JSON line: thread CPU ns per op for every workload, WINDOWS windows of CALLS ops each,
#                    workloads interleaved (order rotates), GC on as in production; plus objects per op.
#   APP_MODE=profile stackprof (cpu) over the workloads: inclusive share of the attribute-set/dirty methods.
require "json"
require File.expand_path("~/workspace/repo/bench/upstream/census/harness.rb")

app = ENV.fetch("APP", "hackatime")
RailsCensus.boot(app)
ops = RailsCensus.workloads(app)
only = ENV["ONLY"]&.split("|")
ops = ops.select { only.include?(_1.name) } if only
run = ->(op) { op.call.call; RailsCensus.reset_side_effects }
warm = Integer(ENV.fetch("WARM", "100"))
ops.each { |op| warm.times { run.(op) } }

if ENV.fetch("APP_MODE", "time") == "profile"
  require "stackprof"
  pat = /LazyIndexedAttributeSet|AttributeMutationTracker|Dirty#|changes_applied|forget_attribute_assignments|IndexedRow/
  out = {}
  ops.each do |op|
    prof = StackProf.run(mode: :cpu, interval: Integer(ENV.fetch("INTERVAL", "50")), raw: true) do
      Integer(ENV.fetch("PROFILE_OPS", "400")).times { run.(op) }
    end
    frames = prof[:frames]
    raw = prof[:raw]
    incl = Hash.new(0)
    selfc = Hash.new(0)
    i = 0
    while i < raw.size
      len = raw[i]
      stack = raw[i + 1, len].map { frames[_1][:name] }
      n = raw[i + 1 + len]
      stack.uniq.each { incl[_1] += n }
      selfc[stack.last] += n
      # Samples with either target on the stack, counted once.
      incl["(LazyIndexedAttributeSet#[] or #keys on stack)"] += n if stack.any? { _1 == "ActiveModel::LazyIndexedAttributeSet#[]" || _1 == "ActiveModel::LazyIndexedAttributeSet#keys" }
      incl["(any LazyIndexedAttributeSet frame on top)"] += n if stack.last.start_with?("ActiveModel::LazyIndexedAttributeSet#")
      i += len + 2
    end
    total = prof[:samples].to_f
    out[op.name] = { samples: prof[:samples], inclusive: incl.select { |k, _| k =~ pat || k.start_with?("(") }.sort_by { -_2 }.first(25).to_h { |k, v| [k, (100 * v / total).round(2)] },
      self_top: selfc.sort_by { -_2 }.first(10).to_h { |k, v| [k, (100 * v / total).round(2)] } }
  end
  puts JSON.generate(arm: ENV["ARM"], ruby: RUBY_DESCRIPTION, profile: out)
  exit
end

windows = Integer(ENV.fetch("WINDOWS", "10"))
calls = Integer(ENV.fetch("CALLS", "20"))
clock = Process::CLOCK_THREAD_CPUTIME_ID
times = ops.to_h { [_1.name, []] }
walls = ops.to_h { [_1.name, []] }
windows.times do |w|
  ops.rotate(w % ops.size).each do |op|
    w0 = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    t0 = Process.clock_gettime(clock, :nanosecond)
    calls.times { run.(op) }
    times[op.name] << (Process.clock_gettime(clock, :nanosecond) - t0) / calls.to_f
    walls[op.name] << (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - w0) / calls.to_f
  end
end
objs = ops.to_h do |op|
  GC.disable
  b = GC.stat(:total_allocated_objects)
  10.times { run.(op) }
  n = (GC.stat(:total_allocated_objects) - b) / 10.0
  GC.enable
  [op.name, n]
end
jit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :invalidation_count) : {}
puts JSON.generate(arm: ENV.fetch("ARM"), round: Integer(ENV.fetch("ROUND", "0")), cols: 0, mode: ENV.fetch("CENSUS_MODE", "interpreter"),
  ruby: RUBY_DESCRIPTION, jit_before: {}, jit_after: {}, ns: times, wall: walls, objects: objs)
