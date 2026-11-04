# frozen_string_literal: true

# Background census, stackprof pass (docs/upstream/background-census.md): the
# census harness's boot and workloads, then per workload a CPU-time stackprof
# window, attributed like the Callgrind sampler (a sample goes to its nearest
# Ruby frame and that frame's line, so C functions count for the Ruby line
# that called them). Wall-clock CPU time, so it is a cross-check of the
# instruction ranking, not a price.
#   ruby -rbundler/setup [--yjit] SCRIPT profile APP NEW_JSON   (STACKPROF_LIB: stackprof's lib dir)
require_relative "../census/harness"

module RailsCensus
  class << self
    def stackprof_profile(name, output)
      raise "fresh output required" if File.exist?(output)
      $LOAD_PATH.unshift(ENV.fetch("STACKPROF_LIB"))
      $LOAD_PATH.unshift(File.expand_path("../../ext/stackprof", ENV.fetch("STACKPROF_LIB")))
      require "stackprof"
      ops = workloads(name)
      only = ENV["CENSUS_ONLY"]&.split(",")
      ops = ops.select { only.include?(_1.name) } if only
      interval = Integer(ENV.fetch("STACKPROF_INTERVAL_US", "1000"))
      # CPU seconds per window. The orb's CPU-time timer fires every few
      # milliseconds whatever the interval, so the window is sized by time.
      seconds = Float(ENV.fetch("STACKPROF_SECONDS", "6"))
      results = ops.map do |op|
        run = -> { op.call.call; reset_side_effects }
        Integer(ENV.fetch("CENSUS_WARMUP", "50")).times { run.call }
        # Enough operations for about `target` samples, from a timed probe.
        started = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
        10.times { run.call }
        per_op = (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - started) / 10
        count = (seconds / per_op).ceil.clamp(10, 200_000)
        GC.start
        cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
        profile = StackProf.run(mode: :cpu, interval: interval, raw: true) { count.times { run.call } }
        cpu_us = (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu) * 1e6 / count
        total = profile[:samples].nonzero? || 1
        { workload: op.name, kind: op.kind, ops: count, interval_us: interval, samples: profile[:samples],
          gc_samples: profile[:gc_samples], cpu_us_per_op: cpu_us,
          sites: lines(profile).map { |(file, line, label), n| { file: file, line: line, method: label, samples: n,
            us_per_op: cpu_us * n / total } } }
      end
      File.write(output, JSON.generate(app: name, ruby: RUBY_DESCRIPTION, mode: mode, rails: rails_sha, workloads: results) + "\n")
    end

    # Self samples per nearest Ruby frame and line (raw stacks are root first).
    def lines(profile)
      frames = profile[:frames]
      raw = profile[:raw]
      raw_lines = profile[:raw_lines]
      counts = Hash.new(0)
      i = 0
      while i < raw.size
        len = raw[i]
        stack = raw[i + 1, len]
        stack_lines = raw_lines[i + 1, len]
        n = raw[i + 1 + len]
        idx = (len - 1).downto(0).find { |j| (f = frames[stack[j]]) && f[:file] && !f[:file].empty? && stack_lines[j] > 0 }
        key = if idx
          f = frames[stack[idx]]
          [site_key(f[:file]), stack_lines[idx], f[:name]]
        else
          ["<no Ruby frame>", 0, frames[stack.last]&.dig(:name)]
        end
        counts[key] += n
        i += len + 2
      end
      counts.sort_by { -_2 }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  command, name, output = ARGV
  RailsCensus.boot(name)
  abort "usage: stackprof_harness.rb profile APP NEW_JSON" unless command == "profile"
  RailsCensus.stackprof_profile(name, output)
end
