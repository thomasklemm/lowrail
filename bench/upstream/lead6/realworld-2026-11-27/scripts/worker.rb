# frozen_string_literal: true

# One measured process: every case, warm, then WINDOWS rounds of interleaved
# windows (case order rotates per window). Each window runs CALLS calls with GC
# off after a GC.start and records thread CPU ns per call. JIT counters are read
# before the first and after the last window, outside timed code. Prints one JSON line.
require "json"
require_relative "setup_model"

warm = Integer(ENV.fetch("WARM", "3000"))
windows = Integer(ENV.fetch("WINDOWS", "15"))
calls = Integer(ENV.fetch("CALLS", "200"))
cases = l6_cases
cases.slice!(*ENV["CASES"].split(",")) if ENV["CASES"]

def jit_counters
  if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    s = RubyVM::ZJIT.stats
    { "zjit" => s.slice(:compiled_iseq_count, :invalidation_count, :invalidation_time_ns, :side_exit_count, :compile_time_ns, :code_region_bytes).transform_keys(&:to_s) }
  elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
    s = RubyVM::YJIT.runtime_stats
    { "yjit" => s.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count, :inline_code_size).transform_keys(&:to_s) }
  else
    {}
  end
end

cases.each_value { |c| warm.times { c.call } }
names = cases.keys
times = names.to_h { [_1, []] }
clock = Process::CLOCK_THREAD_CPUTIME_ID
before = jit_counters
windows.times do |w|
  names.rotate(w % names.size).each do |name|
    call = cases[name]
    GC.start
    GC.disable
    t0 = Process.clock_gettime(clock, :nanosecond)
    i = 0
    while i < calls
      call.call
      i += 1
    end
    t1 = Process.clock_gettime(clock, :nanosecond)
    GC.enable
    times[name] << (t1 - t0) / calls.to_f
  end
end
after = jit_counters
puts JSON.generate(arm: ENV.fetch("ARM"), round: Integer(ENV.fetch("ROUND")), cols: COLS, mode: ENV.fetch("MODE"),
  ruby: RUBY_DESCRIPTION, jit_before: before, jit_after: after, ns: times)
