# frozen_string_literal: true

# Wall time of the CE2 heavier pages (README.md), without Valgrind: one process,
# one app, one Rails tree, one mode (bench/upstream/ce2/walltime runs it).
#   CENSUS_SET=ce2 bundle exec ruby [--yjit] walltime_harness.rb APP OUT_JSON
# Per workload: CE2_WARMUP operations, then CE2_WINDOWS windows of CE2_OPS
# operations each, GC enabled as in production. Per window: wall ms per
# operation, objects per operation, GC runs, and (YJIT) blocks compiled, so a
# window that still compiles can be left out. walltime_summary.rb takes the
# best (fastest) window per process: best of N.
require_relative "../census/harness"

module RailsCensus
  class << self
    def walltime(name, output)
      raise "fresh output required" if File.exist?(output)
      warmup = Integer(ENV.fetch("CE2_WARMUP", "100"))
      windows = Integer(ENV.fetch("CE2_WINDOWS", "7"))
      count = Integer(ENV.fetch("CE2_OPS", "20"))
      ops = workloads(name)
      blocks = -> { RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
      results = ops.map do |op|
        run = -> { op.call.call; reset_side_effects }
        warmup.times { run.call }
        rows = Array.new(windows) do
          g0 = GC.stat
          b0 = blocks.call
          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          count.times { run.call }
          t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
          g1 = GC.stat
          { ms_per_op: t * 1000 / count, objects_per_op: (g1[:total_allocated_objects] - g0[:total_allocated_objects]).fdiv(count),
            gc: g1[:count] - g0[:count], major: g1[:major_gc_count] - g0[:major_gc_count], blocks: blocks.call - b0 }
        end
        { name: op.name, kind: op.kind, warmup: warmup, ops: count, windows: rows }
      end
      File.write(output, JSON.pretty_generate(app: name, ruby: RUBY_DESCRIPTION, mode: mode, yjit: RubyVM::YJIT.enabled?,
        rails: rails_sha, pid: Process.pid, platform: RUBY_PLATFORM, workloads: results) + "\n")
    end
  end
end

if $PROGRAM_NAME == __FILE__
  name, output = ARGV
  abort "usage: CENSUS_SET=ce2 walltime_harness.rb APP OUT_JSON" unless output && RailsCensus.ce2?
  RailsCensus.boot(name)
  RailsCensus.walltime(name, File.expand_path(output))
end
