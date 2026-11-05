# frozen_string_literal: true

require "json"
require "fileutils"

module StackMapPerf
  def self.counters
    return {} unless RubyVM::YJIT.enabled?
    RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count, :code_gc_count)
  end

  def self.measure(work)
    count = Integer(ENV.fetch("CENSUS_REQUESTS", "20"))
    run = ->(n) { n.times { work.call } }
    warmup = Integer(ENV.fetch("CENSUS_WARMUP", "5"))
    run.call(warmup)
    history = []
    if RubyVM::YJIT.enabled?
      flat = 0
      50.times do
        GC.start
        before = counters
        run.call(1)
        history << counters.to_h { |key, value| [key, value - before.fetch(key)] }
        flat = counters == before ? flat + 1 : 0
        break if flat == 3
      end
    end
    path = ENV.fetch("STACK_MAP_OUT")
    ctl, ack = "#{path}.ctl", "#{path}.ack"
    [ctl, ack].each { File.mkfifo(_1) }
    perf = Process.spawn("sudo", "perf", "record", "-e", "cpu-clock", "-F", "997", "--call-graph", "dwarf,16384",
      "--delay=-1", "--control=fifo:#{ctl},#{ack}", "-p", Process.pid.to_s, "-o", "#{path}.perf",
      out: "#{path}.perf.log", err: [:child, :out])
    begin
      File.open(ctl, "w") do |control|
        File.open(ack, "r+") do |reply|
          command = ->(name) do
            control.puts(name)
            control.flush
            response = reply.read(5)
            raise "perf did not acknowledge #{name}: #{response.inspect}" unless response == "ack\n\0"
          end
          command.call("disable")
          GC.start
          run.call(1)
          before = counters
          allocated = GC.stat(:total_allocated_objects)
          gc = GC.count
          times = Process.times
          command.call("enable")
          run.call(count)
          command.call("disable")
          elapsed = Process.times
          result = { ops: count, warmup: warmup, history: history, jit_before: before, jit_after: counters,
            objects_per_op: (GC.stat(:total_allocated_objects) - allocated).fdiv(count), gc_runs: GC.count - gc,
            user_s: elapsed.utime - times.utime, system_s: elapsed.stime - times.stime }
          command.call("stop")
          Process.wait(perf)
          raise "perf failed" unless $?.success?
          result
        end
      end
    ensure
      FileUtils.rm_f([ctl, ack])
    end
  end
end
