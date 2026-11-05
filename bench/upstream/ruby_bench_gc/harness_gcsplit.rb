# Local ruby-bench harness (HARNESS_PATH-style, loaded with -r): per-iteration wall time,
# GC.total_time, minor/major counts and, where GC::Profiler records them, the time of each
# collection split by minor/major; then a fixed-work probe of forced collections.
# Writes one JSON line to $GCSPLIT_OUT.
require_relative ENV.fetch("RUBY_BENCH_DIR") + "/lib/harness"


WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 10))
PROBE_N = Integer(ENV.fetch("GC_PROBE_N", 10))
PROFILE = ENV["GC_PROFILE"] == "1"

puts RUBY_DESCRIPTION

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def stat_now(h)
  GC.stat(h)
  [GC.total_time, h[:minor_gc_count], h[:major_gc_count], h[:marking_time], h[:sweeping_time]]
end

def run_benchmark(_hint, **)
  h = {}
  if PROFILE
    GC::Profiler.configure(max_records: nil) if GC::Profiler.respond_to?(:configure)
    GC::Profiler.enable
  end
  itrs = []
  seq = 0
  (WARMUP_ITRS + BENCH_ITRS).times do |i|
    b = stat_now(h)
    t0 = now
    yield
    wall = now - t0
    a = stat_now(h)
    row = { "wall" => wall, "gc_ns" => a[0] - b[0], "minor" => a[1] - b[1], "major" => a[2] - b[2],
            "mark_ms" => a[3] - b[3], "sweep_ms" => a[4] - b[4] }
    if PROFILE
      recs = GC::Profiler.raw_data
      # Records with GC_SEQUENCE (master); earlier rubies: take everything and clear.
      if recs.first&.key?(:GC_SEQUENCE)
        new = recs.select { |r| r[:GC_SEQUENCE] > seq }
        seq = recs.last[:GC_SEQUENCE] unless recs.empty?
      else
        new = recs
        GC::Profiler.clear
      end
      row["colls"] = new.map { |r| [r[:GC_FLAGS][:major_by] ? 1 : 0, r[:GC_TIME], r[:GC_MARK_WALL_TIME], r[:GC_SWEEP_WALL_TIME]] }
    end
    itrs << row
  end
  GC::Profiler.disable if PROFILE

  # Fixed-work probe: the same number of forced collections on the warmed-up heap.
  probe = {}
  GC.start(full_mark: true, immediate_sweep: true)
  { "minor" => false, "major" => true }.each do |kind, full|
    samples = PROBE_N.times.map do
      g0 = GC.total_time
      w0 = now
      GC.start(full_mark: full, immediate_mark: true, immediate_sweep: true)
      [GC.total_time - g0, now - w0]
    end
    probe[kind] = samples
  end
  require "json"
  File.write(ENV.fetch("GCSPLIT_OUT"), JSON.generate("ruby" => RUBY_DESCRIPTION, "warmup" => WARMUP_ITRS, "itrs" => itrs, "probe" => probe) + "\n")
  puts "GCSPLIT done"
end
