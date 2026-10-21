# frozen_string_literal: true

# Compilation is work, not steady-state request cost. Keep these observations
# outside Callgrind/GC endpoints; retain failed warmups and windows as evidence.
module JitStability
  COUNTERS = %i[compiled_iseq_count compiled_block_count invalidation_count].freeze
  ZJIT_COUNTERS = %i[compiled_iseq_count failed_iseq_count compiled_side_exit_count compile_time_ns invalidation_time_ns invalidation_count].freeze

  def self.mode(value = ENV.fetch("BENCH_JIT", "0"))
    { false => "interpreter", true => "yjit", "0" => "interpreter", "1" => "yjit",
      "interpreter" => "interpreter", "yjit" => "yjit", "zjit" => "zjit" }.fetch(value) {
      raise "BENCH_JIT must be 0, 1, interpreter, yjit or zjit"
    }
  end

  def self.flags(value = mode)
    case mode(value)
    when "interpreter" then %w[--disable-yjit --disable-zjit]
    when "yjit" then %w[--disable-zjit --yjit]
    when "zjit" then %w[--disable-yjit --zjit]
    end
  end

  def self.state
    { yjit: !!RubyVM::YJIT.enabled?, zjit: !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?) }
  end

  def self.actual(worker = state.transform_keys(&:to_s))
    return "both" if worker.fetch("yjit") && worker["zjit"]
    worker.fetch("yjit") ? "yjit" : worker["zjit"] ? "zjit" : "interpreter"
  end

  def self.assert_mode!
    raise "unexpected JIT mode: requested #{mode}, observed #{actual}" unless actual == mode
  end

  def self.enabled? = actual != "interpreter"

  def self.counters(jit)
    jit == "zjit" ? ZJIT_COUNTERS : COUNTERS
  end

  def self.snapshot
    jit = actual
    stats = jit == "zjit" ? RubyVM::ZJIT.stats : RubyVM::YJIT.runtime_stats
    # A missing invalidation count is unknown, not a zero inferred from time.
    counters(jit).to_h { |key| [key, stats[key]] }
  end

  def self.warm
    size = Integer(ENV.fetch("BENCH_JIT_WINDOW", "200"))
    limit = Integer(ENV.fetch("BENCH_JIT_MAX_WARMUP", "20000"))
    raise "JIT warmup needs positive windows" unless size.positive?
    required = [3, (2000 + size - 1) / size].max
    raise "JIT warmup cap must allow 2000 quiet requests and at least three windows" unless limit >= size * required
    history = [{ requests: 0, counters: snapshot }]
    flat = 0
    (limit / size).times do |index|
      yield size
      # The N=0 subtraction endpoint has its own lazy Integer#times exit.
      # Certify it too; it must not first compile inside the empty window.
      yield 0
      3.times { GC.start }
      current = snapshot
      flat = current == history.last.fetch(:counters) ? flat + 1 : 0
      history << { requests: (index + 1) * size, counters: current }
      break if flat >= required
    end
    missing = history.last.fetch(:counters).select { |_, value| !value.is_a?(Integer) }.keys
    { method: "quiet-2000-v2", stable: flat >= required && missing.empty?, observed_counters_flat: flat >= required,
      stop_reason: !missing.empty? ? "missing_counters" : flat >= required ? "quiescent" : "warmup_cap",
      required_flat_windows: required, minimum_quiet_requests: 2000,
      missing_counters: missing, consecutive_flat_windows: flat, window_requests: size,
      max_requests: limit, history: history }
  end

  # JSON worker observations, not the flag passed to Ruby, decide the gate.
  def self.control(workers, requested:)
    requested = mode(requested)
    partial = {} if requested == "zjit"
    observations = workers.to_h do |name, worker|
      actual = actual(worker)
      enabled = actual != "interpreter"
      keys = counters(actual)
      warm = worker["jit_warmup"]
      required = warm ? [3, warm.fetch("required_flat_windows", 3)].max : 3
      warm_ok = !enabled || !!(warm && warm.fetch("stable") && warm.fetch("consecutive_flat_windows") >= required)
      missing = enabled ? keys.reject { |key| worker.fetch("windows").all? { _1.dig("jit_before", key.to_s).is_a?(Integer) } } : []
      windows_ok = !enabled || worker.fetch("windows").all? do |window|
        before, after = window.values_at("jit_before", "jit_after")
        before && after && keys.all? { |key| before[key.to_s].is_a?(Integer) && before[key.to_s] == after[key.to_s] }
      end
      if partial
        available = ZJIT_COUNTERS - [:invalidation_count]
        history = warm ? warm.fetch("history", []).last(4) : []
        warm_flat = history.size == 4 && available.all? do |key|
          values = history.map { _1.dig("counters", key.to_s) }
          values.all? { _1.is_a?(Integer) } && values.uniq.size == 1
        end
        windows = worker.fetch("windows")
        windows_flat = !windows.empty? && windows.all? do |window|
          available.all? do |key|
            before, after = window.dig("jit_before", key.to_s), window.dig("jit_after", key.to_s)
            before.is_a?(Integer) && before == after
          end
        end
        partial[name] = { actual_jit: actual, warmup_stable: warm_flat,
          windows_stable: windows_flat, pass: actual == "zjit" && warm_flat && windows_flat }
      end
      [name, { actual_jit: actual, actual_yjit: worker.fetch("yjit"), missing_counters: missing,
        mode_matched: actual == requested, warmup_stable: warm_ok,
        windows_stable: windows_ok, pass: actual == requested && warm_ok && windows_ok }]
    end
    result = { requested_jit: requested, diagnostic_only: requested == "zjit",
      requested_yjit: requested == "yjit", actual_yjit: workers.values.map { _1.fetch("yjit") }.uniq,
      actual_jit: workers.values.map { actual(_1) }.uniq,
      pass: observations.values.all? { _1.fetch(:pass) }, workers: observations }
    if partial
      result[:partial_gate] = { scope: "available_counter_flatness_only; no invalidation-count proof",
        counters: ZJIT_COUNTERS - [:invalidation_count],
        pass: !partial.empty? && partial.values.all? { _1.fetch(:pass) },
        workers: partial }
    end
    result
  end
end
