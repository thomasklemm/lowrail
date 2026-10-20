# frozen_string_literal: true

# Compilation is work, not steady-state request cost. Keep these observations
# outside Callgrind/GC endpoints; retain failed warmups and windows as evidence.
module JitStability
  COUNTERS = %i[compiled_iseq_count compiled_block_count invalidation_count].freeze

  def self.snapshot
    stats = RubyVM::YJIT.runtime_stats
    COUNTERS.to_h { |key| [key, stats.fetch(key)] }
  end

  def self.warm
    size = Integer(ENV.fetch("BENCH_JIT_WINDOW", "200"))
    limit = Integer(ENV.fetch("BENCH_JIT_MAX_WARMUP", "20000"))
    raise "JIT warmup needs positive windows and at least three windows" unless size.positive? && limit >= size * 3
    history = [{ requests: 0, counters: snapshot }]
    flat = 0
    (limit / size).times do |index|
      yield size
      3.times { GC.start }
      current = snapshot
      flat = current == history.last.fetch(:counters) ? flat + 1 : 0
      history << { requests: (index + 1) * size, counters: current }
      break if flat >= 3
    end
    { stable: flat >= 3, consecutive_flat_windows: flat, window_requests: size,
      max_requests: limit, history: history }
  end

  # JSON worker observations, not the flag passed to Ruby, decide the gate.
  def self.control(workers, requested:)
    observations = workers.transform_values do |worker|
      actual = worker.fetch("yjit")
      warm = worker["jit_warmup"]
      warm_ok = !actual || !!(warm && warm.fetch("stable") && warm.fetch("consecutive_flat_windows") >= 3)
      windows_ok = !actual || worker.fetch("windows").all? do |window|
        before, after = window.values_at("jit_before", "jit_after")
        before && after && COUNTERS.all? { |key| before[key.to_s].is_a?(Integer) && before[key.to_s] == after[key.to_s] }
      end
      { actual_yjit: actual, mode_matched: actual == requested, warmup_stable: warm_ok,
        windows_stable: windows_ok, pass: actual == requested && warm_ok && windows_ok }
    end
    { requested_yjit: requested, actual_yjit: workers.values.map { _1.fetch("yjit") }.uniq,
      pass: observations.values.all? { _1.fetch(:pass) }, workers: observations }
  end
end
