require 'hashie'; require 'logger'
Hashie.logger = Logger.new(nil)
SUF = Hashie::Mash::ALLOWED_SUFFIXES
V = {
  base: ->(m) { m = m.to_s; m.end_with?(*SUF) ? [m[0..-2], m[-1]] : [m, nil] },
  name: ->(m) { m = m.is_a?(Symbol) ? m.name : m.to_s; m.end_with?(*SUF) ? [m[0..-2], m[-1]] : [m, nil] },
  find: ->(m) { m = m.is_a?(Symbol) ? m.name : m.to_s; s = SUF.find { |x| m.end_with?(x) }; s ? [m.chomp(s), s] : [m, nil] },
}
names = %i[private? owner! homepage_ name=]
def t(n = 300_000)
  20_000.times { yield }
  GC.start
  a = GC.stat(:total_allocated_objects); t0 = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
  n.times { yield }
  [(Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - t0) / n * 1e9, (GC.stat(:total_allocated_objects) - a).to_f / n]
end
res = Hash.new { |h, k| h[k] = [] }
5.times { V.each { |k, f| res[k] << t { names.each { |nm| f.(nm) } } } }
res.each { |k, r| printf "%-5s %-6s %7.1f ns  %4.1f objs\n", ARGV[0], k, r.map(&:first).min, r[0][1] }
