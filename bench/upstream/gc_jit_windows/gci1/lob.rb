# GCI1 on lobsters: a background thread sets the interrupt flag every PERIOD µs (as a GC with deferred finalization
# would, at a random point of the request) in the trigger arm; arms alternate iteration by iteration, order flipping
# per pair, GC off per iteration. AA=1: the thread runs but never triggers. Load with -r before benchmark.rb.
require "/home/user/w/ruby-bench/lib/harness"
require File.expand_path("ext/trig", __dir__)

def run_benchmark(_hint, **)
  require "json"
  warm = Integer(ENV.fetch("WARM", "40")); pairs = Integer(ENV.fetch("PAIRS", "25")); aa = ENV["AA"] == "1"
  exits = RubyVM::ZJIT.stats_enabled? ? -> { RubyVM::ZJIT.stats(:exit_interrupt).to_i } : -> { 0 }
  tcpu = -> { Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) }
  Trig.start(Integer(ENV.fetch("PERIOD", "200")))
  it = lambda do |arm|
    GC.start
    GC.disable
    Trig.mode = arm && !aa
    e0 = exits.(); c0 = tcpu.()
    yield
    c1 = tcpu.(); e1 = exits.()
    Trig.mode = false
    GC.enable
    [c1 - c0, e1 - e0]
  end
  warm.times { |j| it.(j.odd?) }
  out = { on: [], off: [], on_exits: 0, off_exits: 0 }
  pairs.times do |j|
    (j.even? ? [true, false] : [false, true]).each do |arm|
      t, e = it.(arm)
      out[arm ? :on : :off] << t
      out[arm ? :on_exits : :off_exits] += e
    end
  end
  File.open(ENV.fetch("OUT"), "a") { |f| f.puts JSON.generate(out.merge(shape: "lobsters", run: ENV["RUN"], aa: aa, ruby: RUBY_DESCRIPTION, trig: Trig.counts)) }
end
