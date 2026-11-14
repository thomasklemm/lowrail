# Wall time per h[:b] (3-pair symbol Hash) and {a: v, b: v, c: v}; ns per iteration minus an empty loop. Interpreter.
h = {a: 1, b: 2, c: 3}
def look(n, h) = (i = 0; x = nil; while i < n; x = h[:b]; i += 1; end; x)
def lit(n, v) = (i = 0; x = nil; while i < n; x = {a: v, b: v, c: v}; i += 1; end; x)
def empty(n, h) = (i = 0; x = nil; while i < n; x = h; i += 1; end; x)
t = ->(m, a) { s = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond); send(m, 5_000_000, a); (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - s) / 5e6 }
3.times { t.(:look, h); t.(:empty, h); t.(:lit, 2) }
r = 7.times.map { [t.(:look, h) - t.(:empty, h), t.(:lit, 2) - t.(:empty, h)] }
med = ->(a) { a.sort[a.size / 2] }
puts format("%s look %.2f ns  lit3 %.2f ns", RUBY_VERSION, med.(r.map(&:first)), med.(r.map(&:last)))
