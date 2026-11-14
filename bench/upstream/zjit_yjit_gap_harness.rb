require_relative "../lib/harness"

# ruby-bench harness for the ZJIT-YJIT gap (docs/upstream/zjit-yjit-gap.md).
# GAP_MODE=callgrind: like ruby_bench_callgrind.rb (an empty window, then a MEASURE_ITRS window; GC counted
#   unless CG_NO_GC=1), plus GC.stat deltas of the measured window, read outside both windows.
# GAP_MODE=stats: WARMUP_ITRS, reset, MIN_BENCH_ITRS; JIT counters (--zjit-stats-quiet / --yjit-stats=quiet),
#   GC.stat deltas and, on the measurement build, interpreted instructions per ISEQ (RubyVM.lowrail_ii_dump).
# Writes JSON to GAP_JSON.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MEASURE_ITRS = Integer(ENV.fetch("MEASURE_ITRS", 3))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 10))
FLAT_WINDOWS = Integer(ENV.fetch("FLAT_WINDOWS", 2))
GAP_KEYS = %i[count minor_gc_count major_gc_count total_allocated_objects total_freed_objects].freeze

puts RUBY_DESCRIPTION

def gap_gc = GC.stat.slice(*GAP_KEYS)

def gap_write(data)
  require "json" # after Bundler.setup: the benchmark may pin another json
  File.write(ENV.fetch("GAP_JSON"), JSON.pretty_generate({ruby: RUBY_DESCRIPTION, jit: (defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? ? "zjit" : defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? "yjit" : "interp")}.merge(data)) + "\n")
end

# JIT-flat gate (docs/bench.md): compile and invalidation counters unchanged over FLAT_WINDOWS consecutive warm
# windows of MEASURE_ITRS iterations before measuring, and over the measured window. ZJIT has no invalidation count;
# every invalidation runs inside its invalidation_time_ns timer (zjit/src/invariants.rs), so that timer stands in.
def gap_jit_counters
  if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    RubyVM::ZJIT.stats.slice(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns)
  elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
    RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count)
  end
end

def gap_heap = GC.stat_heap.to_h { |i, h| [i, h.slice(:slot_size, :heap_eden_pages, :heap_eden_slots)] }

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  if ENV["GAP_MODE"] == "callgrind"
    require "lowrail_callgrind"
    no_gc = ENV["CG_NO_GC"] == "1"
    flat_history = []
    flat = 0
    if (last = gap_jit_counters)
      Integer(ENV.fetch("FLAT_MAX_WINDOWS", 8)).times do
        MEASURE_ITRS.times { block.call }
        now = gap_jit_counters
        flat = now == last ? flat + 1 : 0
        flat_history << now
        last = now
        break if flat == FLAT_WINDOWS
      end
    end
    3.times { GC.start }
    LowrailCallgrindBench.start(no_gc)
    LowrailCallgrindBench.finish
    3.times { GC.start }
    heap_before = gap_heap
    before = gap_gc
    # Read right next to the window: the harness's own GC.stat calls can compile code.
    jit_before = gap_jit_counters
    LowrailCallgrindBench.start(no_gc)
    MEASURE_ITRS.times { block.call }
    segments = LowrailCallgrindBench.finish
    jit_after = gap_jit_counters
    after = gap_gc
    gate = jit_before.nil? ? "n/a" : (flat == FLAT_WINDOWS && jit_before == jit_after ? "pass" : "fail")
    gap_write(itrs: MEASURE_ITRS, gc_segments: segments, gc: after.to_h { |k, v| [k, (v - before[k]).fdiv(MEASURE_ITRS)] },
      jit_flat: { gate:, warm_windows: flat_history, measured_before: jit_before, measured_after: jit_after },
      heap_before:)
  else
    jit = RubyVM::ZJIT.enabled? ? RubyVM::ZJIT : (RubyVM::YJIT if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?)
    ii = RubyVM.respond_to?(:lowrail_ii=) && ENV["GAP_II"] == "1"
    # Whole-process ZJIT memory counters, read before the reset (--zjit-stats counts OOM only).
    pre = jit == RubyVM::ZJIT ? jit.stats.slice(:compile_error_out_of_memory, :failed_iseq_count, :code_region_bytes, :total_mem_bytes, :zjit_alloc_bytes, :compiled_iseq_count, :compile_time_ns, :side_exit_count, :exit_polymorphic_send_miss, :send_fallback_send_polymorphic_fallback) : {}
    jit&.reset_stats!
    RubyVM.lowrail_ii = true if ii
    before = gap_gc
    MIN_BENCH_ITRS.times { block.call }
    after = gap_gc
    dump = RubyVM.lowrail_ii_dump if ii
    RubyVM.lowrail_ii = false if ii
    stats = jit ? (jit == RubyVM::YJIT ? jit.runtime_stats : jit.stats) : {}
    n = MIN_BENCH_ITRS
    per_itr = stats.filter_map { |k, v| [k, v.fdiv(n)] if v.is_a?(Numeric) && v != 0 }.to_h
    post = jit == RubyVM::ZJIT ? jit.stats.slice(:compile_error_out_of_memory, :failed_iseq_count, :code_region_bytes, :total_mem_bytes, :zjit_alloc_bytes, :compiled_iseq_count, :compile_time_ns, :side_exit_count, :exit_polymorphic_send_miss, :send_fallback_send_polymorphic_fallback) : {}
    data = {itrs: n, before_reset: pre, window_end: post, vm_hwm_kb: File.read("/proc/self/status")[/VmHWM:\s+(\d+)/, 1].to_i, per_itr:, gc: after.to_h { |k, v| [k, (v - before[k]).fdiv(n)] }}
    if dump
      data[:interp_iseqs] = dump[0].map { |name, u, c| [name, u.fdiv(n), c.fdiv(n)] }.sort_by { |_, u, c| -(u + c) }
      data[:interp_insns] = dump[1].map { |name, u, c| [name, u.fdiv(n), c.fdiv(n)] }.sort_by { |_, u, c| -(u + c) }
    end
    gap_write(data)
  end
end
