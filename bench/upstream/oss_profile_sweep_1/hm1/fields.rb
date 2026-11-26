a = File.readlines(ARGV[0]).map { eval(_1) }; b = File.readlines(ARGV[1]).map { eval(_1) }
diffs = Hash.new { |h, k| h[k] = [] }
a.zip(b).each do |(l1, s1, k1, r1), (l2, s2, k2, r2)|
  abort "row mismatch #{k1} #{k2}" unless [l1, s1] == [l2, s2] && (k1 == k2 || k1.start_with?("#<Proc"))
  r1.zip(r2).each { |(f, v1), (_, v2)| diffs[f] << [l1, s1, k1, v1, v2] unless v1 == v2 }
end
diffs.each { |f, rows| puts "#{f}: #{rows.size}"; rows.map { |r| [r[3], r[4]] }.tally.sort_by { -_2 }.first(4).each { |(x, y), n| puts "   #{n}x #{x.inspect[0, 140]}\n       -> #{y.inspect[0, 140]}" }; puts "   e.g. #{rows.first[0..2].inspect}" }
