# frozen_string_literal: true

# Census 8 CPU harness: census 7's boot, workloads and warmup, then one sampled
# window per workload under the patched Callgrind (script/cpu-census runs it):
#   ruby -rbundler/setup [--yjit] SCRIPT profile APP NEW_JSON
# Per workload: exact client Ir of the measuring thread (GC included, its
# share reported apart), and Ruby stacks sampled every interval/2..3*interval/2
# Ir. A sample's self cost goes to its nearest Ruby frame and that frame's
# line, so C functions are charged to the Ruby line that called them.
require_relative "../census/harness"

module RailsCensus
  class << self
    def cpu_profile(name, output)
      raise "fresh output required" if File.exist?(output)
      require ENV.fetch("CENSUS_CPU_EXT")
      ops = workloads(name)
      only = ENV["CENSUS_ONLY"]&.split(",")
      ops = ops.select { only.include?(_1.name) } if only
      raise "no workloads selected" if ops.empty?
      results = ops.map { |op| cpu_measure(op) }
      File.write(output, JSON.generate(app: name, ruby: RUBY_DESCRIPTION, mode: mode, yjit: RubyVM::YJIT.enabled?,
        rails: rails_sha, rails_dir: File.basename(rails_dir), adapter: ActiveRecord::Base.connection_db_config.adapter,
        lock_sha256: Digest::SHA256.file(ENV.fetch("BUNDLE_GEMFILE") + ".lock").hexdigest, workloads: results) + "\n")
      puts JSON.generate(results.map { _1.except(:sites, :methods) })
    end

    def jit_counters
      return {} unless RubyVM::YJIT.enabled?
      RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count, :code_gc_count)
    end

    def cpu_measure(op, reset: true)
      run = -> { op.call.call; reset_side_effects if reset }
      warmup = Integer(ENV.fetch("CENSUS_WARMUP", "200"))
      warmup.times { run.call }
      count = Integer(ENV.fetch("CENSUS_REQUESTS", "10"))
      interval = Integer(ENV.fetch("CENSUS_CPU_INTERVAL", "8192"))
      seed = Integer(ENV.fetch("CENSUS_CPU_SEED", "41231"))
      # JIT-flat gate: under YJIT, warm in windows of `count` through the
      # measured window's own block (interval 0: not sampled; sampling does not
      # change what compiles), each after a GC.start like the measured one,
      # until CENSUS_CPU_FLAT windows in a row compile nothing (at most 50 more).
      # The measured window is checked too.
      if RubyVM::YJIT.enabled?
        sampled = ->(every) { CensusCpu.measure(seed, every) { count.times { run.call } } }
        need = Integer(ENV.fetch("CENSUS_CPU_FLAT", "3"))
        flat = 0
        50.times do
          GC.start
          jit = jit_counters
          sampled.call(0)
          warmup += count
          flat = jit_counters == jit ? flat + 1 : 0
          break if flat == need
        end
      end
      jit_pre_gc = jit_counters
      GC.start
      jit_before = jit_counters
      if sampled && ENV["CENSUS_CPU_DIAG"]
        sampled.call(0)
        jit_diag = jit_counters.to_h { |k, v| [k, v - jit_before.fetch(k)] }
        GC.start
        jit_before = jit_counters
      end
      before = GC.stat(:total_allocated_objects)
      gc_before = GC.count
      t0 = Time.now
      window = sampled ? sampled.call(interval) : CensusCpu.measure(seed, interval) { count.times { run.call } }
      jit_log = RubyVM::YJIT.log&.select { _1[0] >= t0 }&.map(&:last) if jit_diag
      objects = GC.stat(:total_allocated_objects) - before
      gc_runs = GC.count - gc_before
      jit_delta = jit_counters.to_h { |k, v| [k, v - jit_before.fetch(k)] }
      frames, stacks = CensusCpu.stacks
      if ENV["CENSUS_CPU_STACKS"]
        File.write(ENV.fetch("CENSUS_CPU_STACKS"), JSON.generate(frames: frames, stacks: stacks, window: window) + "\n")
      end
      keys = frames.map { |path, label, first| [site_key(path), label.to_s, first] }
      weight = window[:work_ir].fdiv(window[:signals].nonzero? || 1) / count
      lines = Hash.new { |h, k| h[k] = [0, 0] }
      self_methods = Hash.new(0)
      inclusive = Hash.new(0)
      stacks.each do |stack, n|
        ruby = stack.index { |id, _| keys[id][0] != "<cfunc>" }
        if ruby
          id, line = stack[ruby]
          file, label, first = keys[id]
          row = lines[[file, line, label]]
          row[0] += n
          row[1] += n if ruby > 0
          self_methods[[file, label, first]] += n
        else
          lines[["<no Ruby frame>", 0, keys[stack[0][0]][1]]][0] += n
        end
        stack.filter_map { |sid, _| keys[sid] unless keys[sid][0] == "<cfunc>" }.uniq.each { inclusive[_1] += n }
      end
      { workload: op.name, kind: op.kind, ops: count, warmup: warmup, interval: interval,
        ir_per_op: window[:work_ir].fdiv(count), gc_ir_per_op: window[:gc] * weight, objects_per_op: objects.fdiv(count),
        gc_runs: gc_runs, window: window, jit_delta: jit_delta,
        jit_gc_delta: jit_pre_gc.to_h { |k, v| [k, jit_before.fetch(k) - v] }, jit_diag_delta: jit_diag, jit_log: jit_log, jit_flat: jit_delta.values.all?(&:zero?),
        sites: lines.sort_by { -_2[0] }.map { |(file, line, label), (n, native)|
          { file: file, line: line, method: label, samples: n, native: native, ir_per_op: n * weight } },
        methods: inclusive.sort_by { -_2 }.map { |(file, label, first), n|
          { file: file, method: label, line: first, self_ir_per_op: self_methods[[file, label, first]] * weight,
            incl_ir_per_op: n * weight } } }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  command, name, output = ARGV
  RailsCensus.boot(name)
  abort "usage: cpu_harness.rb profile APP NEW_JSON" unless command == "profile"
  RailsCensus.cpu_profile(name, output)
end
