require_relative "../lib/harness"

# ruby-bench harness for docs/upstream/zjit-not-equal.md. Needs the measurement build
# (bench/upstream/zne1/neq_count.patch): RubyVM.lowrail_neq*, see lowrail_neq.h there.
# ZNE1_MODE=count: WARMUP_ITRS, then MIN_BENCH_ITRS with the `!=` counters on; rows and ZJIT stats per iteration.
# ZNE1_MODE=cg: under Callgrind (--instr-atstart=no). After warmup and the JIT-flat gate (docs/bench.md), an empty
#   window, a whole-program window and a region window, each of MEASURE_ITRS iterations.
# Writes JSON to ZNE1_JSON.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MEASURE_ITRS = Integer(ENV.fetch("MEASURE_ITRS", 2))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 10))
FLAT_WINDOWS = Integer(ENV.fetch("FLAT_WINDOWS", 2))

puts RUBY_DESCRIPTION

def zne1_jit = RubyVM::ZJIT.enabled? ? RubyVM::ZJIT.stats.slice(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns) : nil

def zne1_write(data)
  require "json" # after Bundler.setup: the benchmark may pin another json
  File.write(ENV.fetch("ZNE1_JSON"), JSON.pretty_generate({ruby: RUBY_DESCRIPTION, zjit: RubyVM::ZJIT.enabled?}.merge(data)) + "\n")
end

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  if ENV["ZNE1_MODE"] == "cg"
    require "lowrail_callgrind"
    flat_history = []
    flat = 0
    if (last = zne1_jit)
      Integer(ENV.fetch("FLAT_MAX_WINDOWS", 8)).times do
        MEASURE_ITRS.times { block.call }
        now = zne1_jit
        flat = now == last ? flat + 1 : 0
        flat_history << now
        last = now
        break if flat == FLAT_WINDOWS
      end
    end
    3.times { GC.start }
    LowrailCallgrindBench.start
    LowrailCallgrindBench.finish
    windows = [false, true].map do |region|
      3.times { GC.start }
      gc = GC.count
      jit = zne1_jit # read next to the window: the harness's own calls can compile code
      LowrailCallgrindBench.start
      RubyVM.lowrail_neq_cg = region # after start: starting instrumentation turns collection back on
      MEASURE_ITRS.times { block.call }
      LowrailCallgrindBench.finish
      state = RubyVM.lowrail_neq_cg_state
      RubyVM.lowrail_neq_cg = false
      after = zne1_jit
      {region:, gcs: GC.count - gc, jit_unchanged: jit == after, jit_delta: jit && after.to_h { |k, v| [k, v - jit[k]] },
       regions: state[0], left_by_jump: state[1], still_on: state[2]}
    end
    gate = last.nil? ? "n/a" : (flat == FLAT_WINDOWS && windows.all? { _1[:jit_unchanged] } ? "pass" : "fail")
    zne1_write(itrs: MEASURE_ITRS, jit_flat: gate, warm_windows: flat_history, windows:)
  else
    RubyVM::ZJIT.reset_stats! if RubyVM::ZJIT.enabled?
    RubyVM.lowrail_neq = true
    MIN_BENCH_ITRS.times { block.call }
    rows = RubyVM.lowrail_neq_dump
    RubyVM.lowrail_neq = false
    stats = RubyVM::ZJIT.enabled? ? RubyVM::ZJIT.stats : {}
    n = MIN_BENCH_ITRS
    keys = %i[send_count dynamic_send_count send_fallback_send_polymorphic send_fallback_send_polymorphic_fallback
              send_fallback_send_megamorphic send_fallback_send_no_profiles zjit_insn_count]
    zne1_write(itrs: n, rows: rows.map { |key, count| [key, count.fdiv(n)] }.sort_by { -_2 },
      per_itr: keys.to_h { [_1, stats.fetch(_1, 0).fdiv(n)] })
  end
end
