# Host-speed probe (wall_noise REF workloads): times an integer loop and a 50k float sort SAMPLES times on this core.
floats = Random.new(1).then { |r| Array.new(50_000) { r.rand } }
ref_loop = -> { x = 0; j = 0; while j < 200_000; x += j & 7; j += 1; end; x }
ref_sort = -> { floats.dup.sort! }
t = -> { Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) }
cpu = File.read("/proc/self/stat").split[38].to_i
steal = -> { File.foreach("/proc/stat").find { _1.start_with?("cpu#{cpu} ") }.split[8].to_i }
30.times { ref_loop.(); ref_sort.() }
GC.disable
n = Integer(ARGV[0] || 600)
s0 = steal.()
rows = n.times.map { a = t.(); ref_loop.(); b = t.(); ref_sort.(); c = t.(); [b - a, c - b] }
s1 = steal.()
q = ->(xs, p) { s = xs.sort; s[(p * (s.size - 1)).round] }
%w[loop sort].each_with_index do |name, i|
  xs = rows.map { _1[i] }
  m = q.(xs, 0.5)
  printf "%s cpu%d n=%d median %.3f ms  p10/median %.3f  p90/median %.3f  max/median %.3f  slow(>1.05x median) %d\n",
    name, cpu, n, m * 1e3, q.(xs, 0.1) / m, q.(xs, 0.9) / m, xs.max / m, xs.count { _1 > 1.05 * m }
end
puts "steal ticks on cpu#{cpu}: #{s1 - s0}"
