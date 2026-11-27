# GCI1 micro: cost of one ZJIT interrupt exit plus what follows it. GC off per window, arms alternate window by window
# (order flips per pair), thread CPU time per window. Prints one JSON line.
# SHAPE=early|late: Trig.set before (the whole 2,000-iteration loop then finishes in the interpreter) or after the
#   loop (only the return is interpreted); the control arm calls Trig.noop at the same place. AA=1: both arms noop.
# SHAPE=fk: E2's foreign_keys, 70 calls per window; a background thread sets the interrupt every PERIOD µs in the
#   trigger arm (Trig.mode), so exits land wherever the work is, as a GC's would. AA=1: mode stays off.
require "json"
require File.expand_path("ext/trig", __dir__)
shape = ENV.fetch("SHAPE", "early")
pairs = Integer(ENV.fetch("PAIRS", "400"))
aa = ENV["AA"] == "1"

if shape == "fk"
  require "active_record"
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  c = ActiveRecord::Base.lease_connection
  c.transaction do
    1000.times do |i|
      c.execute %(CREATE TABLE "t#{i}" ("id" integer PRIMARY KEY, "name" text, "parent_id" integer, CONSTRAINT "fk_t#{i}" FOREIGN KEY ("parent_id") REFERENCES "t#{i}" ("id")))
      c.execute %(CREATE INDEX "index_t#{i}_on_parent_id" ON "t#{i}" ("parent_id"))
    end
  end
  tables = 1000.times.map { "t#{_1}" }
  k = 0
  work = lambda do |_arm|
    j = 0
    while j < 70
      c.foreign_keys(tables[(k += 1) % 1000])
      j += 1
    end
  end
  set_arm = ->(on) { Trig.mode = on && !aa }
  Trig.start(Integer(ENV.fetch("PERIOD", "20")))
else
  class Work
    def f(i) = (i & 7) + 1
    def g(a, i) = a + f(i)
    def early(on)
      on ? Trig.set : Trig.noop
      a = 0; i = 0
      while i < 2000
        a = g(a, i); i += 1
      end
      a
    end
    def late(on)
      a = 0; i = 0
      while i < 2000
        a = g(a, i); i += 1
      end
      on ? Trig.set : Trig.noop
      a
    end
  end
  w = Work.new
  m = shape.to_sym
  work = ->(arm) { w.public_send(m, arm && !aa) }
  set_arm = ->(_) {}
end

tcpu = -> { Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) }
exits = RubyVM::ZJIT.stats_enabled? ? -> { RubyVM::ZJIT.stats(:exit_interrupt).to_i } : -> { 0 }
window = lambda do |arm|
  GC.start
  GC.disable
  set_arm.(arm)
  e0 = exits.(); c0 = tcpu.()
  work.(arm)
  c1 = tcpu.(); e1 = exits.()
  set_arm.(false)
  GC.enable
  [c1 - c0, e1 - e0]
end
(shape == "fk" ? 60 : 600).times { |j| window.(j.odd?) }
out = { on: [], off: [], on_exits: 0, off_exits: 0 }
pairs.times do |j|
  (j.even? ? [true, false] : [false, true]).each do |arm|
    t, e = window.(arm)
    out[arm ? :on : :off] << t
    out[arm ? :on_exits : :off_exits] += e
  end
end
puts JSON.generate(out.merge(shape: shape, aa: aa, ruby: RUBY_DESCRIPTION, trig: Trig.counts))
