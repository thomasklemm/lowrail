require_relative "../lib/harness"

# ruby-bench harness for the #17251 split (installed as harness/split.rb): WARMUP_ITRS warmups, then BENCH_ITRS
# measured iterations, fixed per benchmark so every build does the same work. Writes one JSON to GCSTEP_OUT with
# per-iteration times and RSS, GC.stat over the measured window and over the whole run, and, with GCMAJORS_SO, one
# record per completed GC from the start of the warmup (vs17251-2026-11-24/gcmajors).
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
BENCH_ITRS = Integer(ENV.fetch("BENCH_ITRS", 30))

def statm_rss_kb = File.read("/proc/self/statm").split[1].to_i * 4
def status_kb(key) = File.read("/proc/self/status")[/^#{key}:\s+(\d+)/, 1].to_i

def run_benchmark(_hint, **)
  require "json"
  require ENV["GCMAJORS_SO"] if ENV["GCMAJORS_SO"]
  keys = %i[count minor_gc_count major_gc_count time]
  GCMajors.start if ENV["GCMAJORS_SO"]
  run0 = GC.stat.slice(*keys)
  warm = WARMUP_ITRS.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
  end
  before = GC.stat.slice(*keys)
  nwarm = GCMajors.count if ENV["GCMAJORS_SO"]
  rss0 = statm_rss_kb
  rss = []
  times = BENCH_ITRS.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
    rss << statm_rss_kb
    dt
  end
  after = GC.stat.slice(*keys)
  gcs = GCMajors.records if ENV["GCMAJORS_SO"]
  hwm = status_kb("VmHWM")
  rss_end = statm_rss_kb
  # ruby-bench's own RSS figure: Rss from smaps_rollup after a full GC at the end.
  GC.start(full_mark: true, immediate_sweep: true)
  out = {
    ruby: RUBY_DESCRIPTION, warmup_itrs: WARMUP_ITRS, bench_itrs: BENCH_ITRS,
    warmup_s: warm, times_s: times,
    bench: keys.to_h { [_1, after[_1] - before[_1]] },
    run: keys.to_h { [_1, after[_1] - run0[_1]] }, process: after,
    rss_kb_start: rss0, rss_kb: rss, rss_kb_end: rss_end, vmhwm_kb: hwm,
    rss_kb_after_full_gc: get_rss / 1024,
    gcs_warmup: nwarm, gcs: gcs,
  }
  File.write(ENV.fetch("GCSTEP_OUT"), JSON.generate(out))
end
