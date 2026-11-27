require_relative "../lib/harness"

# ruby-bench harness for bench/upstream/zjit_gap_bet/HANDOFF.md: wall time per iteration in one fresh process, with the
# JIT-flat gate. WARMUP_ITRS iterations, then MEASURE_ITRS timed iterations; the JIT's compile and invalidation
# counters are read around every timed iteration and over the last FLAT_ITRS warmup iterations. GC stays on, as in
# ruby-bench's default harness, and its time per iteration is recorded next to the wall time. Writes JSON to WALL_JSON.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MEASURE_ITRS = Integer(ENV.fetch("MEASURE_ITRS", 10))
FLAT_ITRS = Integer(ENV.fetch("FLAT_ITRS", 6))

puts RUBY_DESCRIPTION

def wall_jit
  if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? then "zjit"
  elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? then "yjit"
  else "interp"
  end
end

# ZJIT has no invalidation count; every invalidation runs inside its invalidation_time_ns timer.
def wall_counters
  case wall_jit
  when "zjit" then RubyVM::ZJIT.stats.slice(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns)
  when "yjit" then RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count)
  end
end

def wall_now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

# Warmup and timed iterations run through the same loop, so the loop itself is compiled long before it is timed.
def run_benchmark(_num_itrs_hint, **, &block)
  total = WARMUP_ITRS + MEASURE_ITRS
  all = []
  i = 0
  while i < total
    gc = GC.total_time
    count = GC.count
    t = wall_now
    block.call
    ns = wall_now - t
    all << { ms: ns / 1e6, gc_ms: (GC.total_time - gc) / 1e6, gcs: GC.count - count, counters: wall_counters }
    i += 1
  end
  itrs = all.last(MEASURE_ITRS)
  # Counters after the iteration before the flat window, through the last timed one.
  flat_warm = all[WARMUP_ITRS - FLAT_ITRS - 1...WARMUP_ITRS].map { _1[:counters] }.uniq.size <= 1
  flat = all[WARMUP_ITRS - 1..].map { _1[:counters] }.uniq.size <= 1
  # 1-based iterations after which the counters differed from the iteration before.
  changes = all.each_cons(2).with_index.select { |(a, b), _| a[:counters] != b[:counters] }.map { _2 + 2 }
  itrs.each_with_index { |itr, k| itr[:flat] = !changes.include?(WARMUP_ITRS + k + 1) }
  require "json" # after Bundler.setup: the benchmark may pin another json
  File.write(ENV.fetch("WALL_JSON"), JSON.pretty_generate(ruby: RUBY_DESCRIPTION, jit: wall_jit, warmup: WARMUP_ITRS,
    gate: wall_counters.nil? ? "n/a" : (flat_warm && flat ? "pass" : "fail"), flat_warm:, flat_measured: flat,
    counter_change_itrs: changes, counters: wall_counters, warm_ms: all.first(WARMUP_ITRS).map { _1[:ms].round(2) },
    itrs: itrs.map { _1.except(:counters) }, vm_hwm_kb: File.read("/proc/self/status")[/VmHWM:\s+(\d+)/, 1].to_i) + "\n")
  puts "gate #{flat_warm && flat ? "pass" : "fail"} mean #{(itrs.sum { _1[:ms] } / itrs.size).round(1)} ms, counters last moved in iteration #{changes.last}"
end
