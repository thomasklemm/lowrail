require_relative "../lib/harness"


# Sweep-step measurement: WARMUP_ITRS warmup, then BENCH_ITRS iterations with
# GC.__step_log on (instrumented Ruby only) and GC/RSS deltas over that window.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
BENCH_ITRS = Integer(ENV.fetch("BENCH_ITRS", 30))

def rss_kb = File.read("/proc/self/statm").split[1].to_i * 4

def run_benchmark(_hint, **)
  require "json"
  # GCMAJORS_SO: per-GC records (vs17251-2026-11-24/gcmajors), for attributing majors and their time.
  require ENV["GCMAJORS_SO"] if ENV["GCMAJORS_SO"]
  WARMUP_ITRS.times { yield }
  GC.start
  keys = %i[count minor_gc_count major_gc_count time heap_allocated_pages total_allocated_objects]
  before = GC.stat.slice(*keys)
  rss0 = rss_kb
  peak = rss0
  log = ENV["GCSTEP_LOG"] if GC.respond_to?(:__step_log)
  GC.__step_log(true) if log
  old0 = GC.stat.values_at(:old_objects, :old_objects_limit) if ENV["GCMAJORS_SO"]
  GCMajors.start if ENV["GCMAJORS_SO"]
  times = BENCH_ITRS.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
    peak = [peak, rss_kb].max
    dt
  end
  GC.__step_log(false) if log
  gcs = GCMajors.records if ENV["GCMAJORS_SO"]
  File.rename("#{log}.#{Process.pid}", "#{log}.bin") if log && File.exist?("#{log}.#{Process.pid}")
  after = GC.stat.slice(*keys)
  out = keys.to_h { [_1, after[_1] - before[_1]] }.merge(
    itrs: BENCH_ITRS, wall_s: times.sum, rss_kb_start: rss0, rss_kb_end: rss_kb, rss_kb_peak: peak,
    pool_mode: (GC.__pool_mode if GC.respond_to?(:__pool_mode)), ruby: RUBY_DESCRIPTION, gcs_old0: old0, gcs: gcs)
  File.write(ENV.fetch("GCSTEP_OUT"), JSON.generate(out))
end
