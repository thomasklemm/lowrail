# ruby -Igem/lib margin.rb BASE HEAD AA: rows compared and the closest ones to their floor (|delta| / floor).
require "json"
require "lowrail/profile_compare"
c = Lowrail::ProfileCompare.new(*ARGV.first(2), aa: ARGV[2], min: 1.0, top: 30)
ch = c.send(:changes)
lines, actions = ch.partition { _1.what == "line" }
puts "status #{c.status} compared: #{lines.size} lines, #{actions.size} actions; not compared #{c.send(:not_compared).size}"
ch.sort_by { -_1.delta.abs / _1.threshold(1.0) }.first(4).each do |x|
  printf "  %s %s %s: %+.2f against %.2f (%.0f%%)\n", x.kind, x.what, x.name, x.delta, x.threshold(1.0), 100 * x.delta.abs / x.threshold(1.0)
end
