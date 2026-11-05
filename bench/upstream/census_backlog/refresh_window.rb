# frozen_string_literal: true

require "json"
load File.join(__dir__, "refresh_cases.rb")
require ENV["CG_EXT"] if ENV["CG_EXT"]

def window(work, count)
  count.times { work.call }
end

def compilations
  if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    stats = RubyVM::ZJIT.stats
    [stats.fetch(:compiled_iseq_count), stats.fetch(:compiled_side_exit_count), stats.fetch(:compile_error_out_of_memory)]
  elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
    stats = RubyVM::YJIT.runtime_stats
    [stats.fetch(:compiled_iseq_count), stats.fetch(:compiled_block_count)]
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

name, count = ARGV.fetch(0), Integer(ARGV.fetch(1))
work = MICRO.fetch(name).call
flat = 0
50.times do
  GC.start
  GC.disable
  sample = observe(work, 2000)
  GC.enable
  flat = sample.fetch(:flat) ? flat + 1 : 0
  break if flat == 3
end
raise "warmup not JIT flat" unless flat == 3

samples = []
Integer(ENV.fetch("SAMPLES", "1")).times do
  GC.start
  GC.disable
  LowrailCallgrindBench.start if ENV["CG_EXT"]
  sample = observe(work, count)
  LowrailCallgrindBench.finish if ENV["CG_EXT"]
  GC.enable
  samples << sample
end
puts JSON.generate(ruby: RUBY_DESCRIPTION, tree: ENV.fetch("RAILS_PATH"), case: name, count: count, samples: samples)
