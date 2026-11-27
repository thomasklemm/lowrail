require 'hashie'; require 'json'; require 'logger'
Hashie.logger = Logger.new(nil)
src = JSON.parse(File.read('benchmarks/fixtures/repository.json'))
def t(label, n = 20000)
  2000.times { yield }
  a = GC.stat(:total_allocated_objects); t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { yield }
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  printf "%-28s %8.2f us  %6.2f objs\n", label, (t1 - t0) / n * 1e6, (GC.stat(:total_allocated_objects) - a).to_f / n
end
puts RUBY_DESCRIPTION
V = {
  'A keep keys' => Class.new(Hashie::Mash) { def dup; copy = regular_dup; each_pair { |k, v| copy.regular_writer(k, convert_value(v, true)) }; copy; end },
  'C clear+convert_key' => Class.new(Hashie::Mash) { def dup; copy = regular_dup.clear; each_pair { |k, v| copy.regular_writer(convert_key(k), convert_value(v, true)) }; copy; end },
  'D copy receiver' => Class.new(Hashie::Mash) { def dup; copy = regular_dup.clear; each_pair { |k, v| copy.regular_writer(copy.convert_key(k), copy.convert_value(v, true)) }; copy; end },
}
m = Hashie::Mash.new(src); t('current dup') { m.dup }
V.each { |l, k| m = k.new(src); t(l) { m.dup } }
