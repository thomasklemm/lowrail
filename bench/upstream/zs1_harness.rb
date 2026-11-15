require_relative "../lib/harness"

# ruby-bench harness for docs/upstream/zjit-symbol-block.md. Needs the measurement build
# (bench/upstream/zs1_symbol_block.patch): RubyVM.lowrail_sb*, see lowrail_sb.h there.
# ZS1_MODE=count: WARMUP_ITRS, then MIN_BENCH_ITRS with the Symbol block counters on; rows and ZJIT stats per iteration.
# ZS1_MODE=cg: under Callgrind (--instr-atstart=no). After warmup and the JIT-flat gate (docs/bench.md), an empty
#   window, a whole-program window and one window per region mask in ZS1_MASKS, each of MEASURE_ITRS iterations.
# Writes JSON to ZS1_JSON.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MEASURE_ITRS = Integer(ENV.fetch("MEASURE_ITRS", 3))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 10))
FLAT_WINDOWS = Integer(ENV.fetch("FLAT_WINDOWS", 2))
ZS1_MASKS = ENV.fetch("ZS1_MASKS", "1,2,4,8").split(",").map { Integer(_1) }

puts RUBY_DESCRIPTION

def zs1_jit = RubyVM::ZJIT.enabled? ? RubyVM::ZJIT.stats.slice(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns) : nil

def zs1_write(data)
  require "json" # after Bundler.setup: the benchmark may pin another json
  File.write(ENV.fetch("ZS1_JSON"), JSON.pretty_generate({ruby: RUBY_DESCRIPTION, zjit: RubyVM::ZJIT.enabled?}.merge(data)) + "\n")
end

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  if ENV["ZS1_MODE"] == "cg"
    require "lowrail_callgrind"
    flat_history = []
    flat = 0
    if (last = zs1_jit)
      Integer(ENV.fetch("FLAT_MAX_WINDOWS", 8)).times do
        MEASURE_ITRS.times { block.call }
        now = zs1_jit
        flat = now == last ? flat + 1 : 0
        flat_history << now
        last = now
        break if flat == FLAT_WINDOWS
      end
    end
    3.times { GC.start }
    LowrailCallgrindBench.start
    LowrailCallgrindBench.finish
    windows = ([0] + ZS1_MASKS).map do |mask|
      3.times { GC.start }
      gc = GC.count
      jit = zs1_jit # read next to the window: the harness's own calls can compile code
      LowrailCallgrindBench.start
      RubyVM.lowrail_sb_cg = mask # after start: starting instrumentation turns collection back on
      MEASURE_ITRS.times { block.call }
      LowrailCallgrindBench.finish
      state = RubyVM.lowrail_sb_cg_state
      RubyVM.lowrail_sb_cg = 0
      after = zs1_jit
      {mask:, gcs: GC.count - gc, jit_unchanged: jit == after, jit_delta: jit && after.to_h { |k, v| [k, v - jit[k]] },
       regions: state[0], left_by_jump: state[1], still_on: state[2]}
    end
    gate = last.nil? ? "n/a" : (flat == FLAT_WINDOWS && windows.all? { _1[:jit_unchanged] } ? "pass" : "fail")
    zs1_write(itrs: MEASURE_ITRS, jit_flat: gate, warm_windows: flat_history, windows:)
  else
    RubyVM::ZJIT.reset_stats! if RubyVM::ZJIT.enabled?
    RubyVM.lowrail_sb = true
    MIN_BENCH_ITRS.times { block.call }
    rows = RubyVM.lowrail_sb_dump
    RubyVM.lowrail_sb = false
    stats = RubyVM::ZJIT.enabled? ? RubyVM::ZJIT.stats : {}
    n = MIN_BENCH_ITRS
    zs1_write(itrs: n, rows: rows.map { |key, count| [key, count.fdiv(n)] }.sort_by { -_2 },
      per_itr: stats.filter_map { |k, v| [k, v.fdiv(n)] if v.is_a?(Numeric) && v != 0 }.to_h)
  end
end
