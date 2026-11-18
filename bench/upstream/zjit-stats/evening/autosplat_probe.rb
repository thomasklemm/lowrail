# Auto-splat into an inlined Array#find: ruby --zjit --zjit-stats-quiet autosplat_probe.rb outer_local|outer_local1|no_outer|outer_lit
H = [[Range, :r], [Array, :a], [String, :s], [Integer, :i]]
def outer_local(o) = H.find { |k, _| k === o }
def outer_local1(o) = H.find { |k| k[0] === o }
def no_outer(o) = H.find { |k, _| k == Integer }
def outer_lit(o) = H.find { |k, _| k === 1 }
20.times { |i| [3].find { |x| x == 3 }; [4].find { |x| x.odd? } }
c = ARGV[0].to_sym
2000.times { send(c, 1) }
RubyVM::ZJIT.reset_stats!
10000.times { send(c, 1) }
s = RubyVM::ZJIT.stats
puts "#{c} " + s.select { |k, v| v.is_a?(Integer) && v > 0 && k =~ /send_fallback|dynamic_send|direct|inline_reject|exit_/ }.map { "#{_1}=#{_2}" }.join(" ")
