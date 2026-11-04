ARGV2 = ARGV.dup
src = File.read(File.join(__dir__, "harness2.rb")).split(/^# ---- Load Rails -/).first
ARGV.replace(["/dev/null"]); eval(src, binding, "harness2.rb")
a = File.foreach(ARGV2[0]).to_h { |l| k, v = l.scrub.chomp.split("\t", 2); [k, v] }
b = File.foreach(ARGV2[1]).to_h { |l| k, v = l.scrub.chomp.split("\t", 2); [k, v] }
ids = a.keys.select { _1.start_with?("sql/") && a[_1] != b[_1] }.map { _1.split("/").last.to_i }.uniq.sort
ops = ids.map { |i| [i, AR_INPUTS2[i].map(&:first)] }
p ops.map { _2 }.flatten.tally.sort_by { -_2 }
show = ARGV2[2].to_s.split(",").map(&:to_i)
show.each { |i| puts "#{i}: #{AR_INPUTS2[i].inspect}"; %w[sqlite rows].each { |s| puts "  #{s} 81:   #{a["sql/#{s}/#{i}"].to_s[0, 600]}\n  #{s} main: #{b["sql/#{s}/#{i}"].to_s[0, 600]}" } }
rest = ids.reject { |i| o = AR_INPUTS2[i]; o.any? { |op, arg| op == :where_tuple && arg.empty? } || (o.any? { _1[0] == :includes } && o.any? { %i[joins left_joins where_assoc merge].include?(_1[0]) }) }
puts "unexplained: #{rest.inspect}"
rest.first(6).each { |i| puts "#{i}: #{AR_INPUTS2[i].inspect}"; %w[sqlite pg rows].each { |s| x = a["sql/#{s}/#{i}"].to_s; y = b["sql/#{s}/#{i}"].to_s; next if x == y; pre = x.chars.zip(y.chars).take_while { _1 == _2 }.size; puts "  #{s} at #{pre}:\n    81:   …#{x[[pre - 80, 0].max, 400]}\n    main: …#{y[[pre - 80, 0].max, 400]}" } }
