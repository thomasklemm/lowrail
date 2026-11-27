a = (1..12).to_a
f1 = -> { h = {}; a.each { |x| h[x] = x }; h }
f2 = -> { a.to_h { |x| [x, x] } }
f3 = -> { h = Hash.new(capacity: a.size); a.each { |x| h[x] = x }; h }
[["each", f1], ["to_h", f2], ["capacity", f3]].each do |n, f|
  1000.times { f.() }; GC.start; b = GC.stat(:total_allocated_objects); 10000.times { f.() }; o = (GC.stat(:total_allocated_objects) - b) / 10000.0
  t = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID); 200_000.times { f.() }; t = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t
  puts format("%-9s objects %.1f  %5.0f ns", n, o, t / 200_000 * 1e9)
end
