# Fixed work timed repeatedly on one core: the spread is host noise, not Ruby's.
t = ->(&b) { c = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID); w = Process.clock_gettime(Process::CLOCK_MONOTONIC); b.call; [Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - c, Process.clock_gettime(Process::CLOCK_MONOTONIC) - w] }
GC.disable
xs = Array.new(120) { t.() { i = 0; s = 0; while i < 5_000_000; s += i; i += 1; end } }
cpu = xs.map(&:first).sort
wall = xs.map(&:last).sort
f = ->(a) { format("min %.2f ms  p50 %.2f  p90 %.2f  max %.2f  max/min %.3f", a[0] * 1e3, a[a.size / 2] * 1e3, a[(a.size * 0.9).floor] * 1e3, a[-1] * 1e3, a[-1] / a[0]) }
puts "cpu  #{f.(cpu)}", "wall #{f.(wall)}"
puts "per-sample cpu ms: #{xs.map { (_1[0] * 1e3).round(2) }.join(" ")}"
