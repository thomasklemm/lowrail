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
GAP_KEYS = %i[count minor_gc_count major_gc_count total_allocated_objects total_freed_objects].freeze

puts RUBY_DESCRIPTION

def gap_gc = GC.stat.slice(*GAP_KEYS)

def gap_write(data)
  require "json" # after Bundler.setup: the benchmark may pin another json
  File.write(ENV.fetch("GAP_JSON"), JSON.pretty_generate({ruby: RUBY_DESCRIPTION, jit: (RubyVM::ZJIT.enabled? ? "zjit" : defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? "yjit" : "interp")}.merge(data)) + "\n")
end

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  if ENV["GAP_MODE"] == "callgrind"
    require "lowrail_callgrind"
    no_gc = ENV["CG_NO_GC"] == "1"
    3.times { GC.start }
    LowrailCallgrindBench.start(no_gc)
    LowrailCallgrindBench.finish
    3.times { GC.start }
    before = gap_gc
    LowrailCallgrindBench.start(no_gc)
    MEASURE_ITRS.times { block.call }
    segments = LowrailCallgrindBench.finish
    after = gap_gc
    gap_write(itrs: MEASURE_ITRS, gc_segments: segments, gc: after.to_h { |k, v| [k, (v - before[k]).fdiv(MEASURE_ITRS)] })
  else
    jit = RubyVM::ZJIT.enabled? ? RubyVM::ZJIT : (RubyVM::YJIT if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?)
    ii = RubyVM.respond_to?(:lowrail_ii=) && ENV["GAP_II"] == "1"
    # Whole-process ZJIT memory counters, read before the reset (--zjit-stats counts OOM only).
    pre = jit == RubyVM::ZJIT ? jit.stats.slice(:compile_error_out_of_memory, :failed_iseq_count, :code_region_bytes, :total_mem_bytes) : {}
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
    post = jit == RubyVM::ZJIT ? jit.stats.slice(:compile_error_out_of_memory, :failed_iseq_count, :code_region_bytes, :total_mem_bytes) : {}
    data = {itrs: n, before_reset: pre, window_end: post, per_itr:, gc: after.to_h { |k, v| [k, (v - before[k]).fdiv(n)] }}
    if dump
      data[:interp_iseqs] = dump[0].map { |name, u, c| [name, u.fdiv(n), c.fdiv(n)] }.sort_by { |_, u, c| -(u + c) }
      data[:interp_insns] = dump[1].map { |name, u, c| [name, u.fdiv(n), c.fdiv(n)] }.sort_by { |_, u, c| -(u + c) }
    end
    gap_write(data)
  end
end
