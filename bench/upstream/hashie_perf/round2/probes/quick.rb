# Quick objects and best-of-15 CPU time per call for a body script: ruby [--yjit] -I TREE/lib quick.rb BODY.rb (screening only; no A/A)
module UpstreamBench
  CASES = {}
  def self.report(name, &block) = CASES[name.to_s] = block
end
load ARGV[0]
UpstreamBench::CASES.each do |name, call|
  3000.times { call.call }
  GC.start; GC.disable
  c = [1000, 2000].map { |n| b = GC.stat(:total_allocated_objects); n.times { call.call }; GC.stat(:total_allocated_objects) - b }
  GC.enable
  best = Float::INFINITY
  n = 2000
  15.times do
    GC.start; GC.disable
    t = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
    i = 0
    while i < n; call.call; i += 1; end
    e = (Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - t) / n
    GC.enable
    best = e if e < best
  end
  puts format('%-28s %8.2f objects %10.3f us', name, (c[1] - c[0]) / 1000.0, best * 1e6)
end
