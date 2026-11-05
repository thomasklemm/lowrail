# What GC::Profiler adds to a collection: forced minor GCs on a heap with some live objects,
# alternating profiler off and on, GC.total_time per collection.
# usage: ruby profiler_cost.rb [ROUNDS]
live = Array.new(200_000) { |i| "s#{i}" }
rounds = Integer(ARGV.fetch(0, 10))
per = 200

def gc_ns(n)
  t = GC.total_time
  w = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  n.times { 1000.times { Object.new }; GC.start(full_mark: false, immediate_mark: true, immediate_sweep: true) }
  [(GC.total_time - t) / n, (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - w) / n]
end

gc_ns(per)
off = []; on = []
rounds.times do
  GC::Profiler.disable
  off << gc_ns(per)
  GC::Profiler.enable
  on << gc_ns(per)
  GC::Profiler.clear
end
med = ->(a, i) { a.map { _1[i] }.sort[a.size / 2] }
puts format("profiler off: %d ns GC, %d ns wall per collection", med.(off, 0), med.(off, 1))
puts format("profiler on:  %d ns GC, %d ns wall per collection", med.(on, 0), med.(on, 1))
puts format("difference:   %+d ns GC, %+d ns wall", med.(on, 0) - med.(off, 0), med.(on, 1) - med.(off, 1))
live.size
