# frozen_string_literal: true

require "json"
load ENV.fetch("CASES", File.join(__dir__, "refresh_cases.rb"))
require ENV["CG_EXT"] if ENV["CG_EXT"]
if ENV["FIXED_HEAP"]
  require_relative "../../heap_windows"
  heap_anchors = HeapWindows.prepare_heap
end

def window(work, count)
  count.times { work.call }
end

def compilations
  if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    stats = RubyVM::ZJIT.stats
    [stats.fetch(:compiled_iseq_count), stats.fetch(:compiled_side_exit_count), stats.fetch(:compile_error_out_of_memory)]
  elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
    stats = RubyVM::YJIT.runtime_stats
    [stats.fetch(:compiled_iseq_count), stats.fetch(:compiled_block_count), stats.fetch(:invalidation_count)]
  else
    []
  end
end

def observe(work, count)
  before = compilations
  objects = GC.stat(:total_allocated_objects)
  started = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID, :nanosecond)
  window(work, count)
  duration = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID, :nanosecond) - started
  objects = GC.stat(:total_allocated_objects) - objects
  after = compilations
  { objects: objects.fdiv(count), ns: duration.fdiv(count), before: before, after: after, flat: before == after }
end

ARGV.fetch(0).split(",").each do |name|
  count = Integer(ARGV.fetch(1))
  work = MICRO.fetch(name).call
  flat = 0
  history = []
  50.times do
    GC.start
    GC.disable unless ENV["FIXED_HEAP"]
    sample = observe(work, Integer(ENV.fetch("WINDOW_WARMUP", "2000")))
    GC.enable
    history << sample.values_at(:before, :after)
    flat = sample.fetch(:flat) ? flat + 1 : 0
    break if flat == 3
  end
  raise "warmup not JIT flat: #{name}" unless flat == 3

  samples = []
  Integer(ENV.fetch("SAMPLES", "1")).times do
    GC.start
    GC.disable
    heap_before = GC.stat_heap.transform_values { _1.fetch(:heap_eden_slots) }
    LowrailCallgrindBench.start if ENV["CG_EXT"]
    sample = observe(work, count)
    LowrailCallgrindBench.finish if ENV["CG_EXT"]
    heap_after = GC.stat_heap.transform_values { _1.fetch(:heap_eden_slots) }
    GC.enable
    samples << sample.merge(heap_before: heap_before, heap_after: heap_after)
  end
  puts JSON.generate(ruby: RUBY_DESCRIPTION, tree: ENV.fetch("RAILS_PATH"), case: name, count: count, anchors: heap_anchors&.size,
    warmup_count: Integer(ENV.fetch("WINDOW_WARMUP", "2000")), warmup: history, samples: samples)
  STDOUT.flush
end
