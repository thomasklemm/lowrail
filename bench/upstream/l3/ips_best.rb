# ips_best.rb FILE: best i/s per tree and case from ips_rounds.sh output, the fix against main, and main2 against main (A/A).
best = Hash.new { |h, k| h[k] = {} }
File.foreach(ARGV[0]) do |line|
  next unless line =~ /\A(\S+) r\d+: +(.+?) +([\d.]+)([kM]?) \(/
  ips = $3.to_f * { "k" => 1e3, "M" => 1e6, "" => 1 }.fetch($4)
  best[$2][$1] = [best[$2][$1] || 0, ips].max
end
best.each do |name, trees|
  fix = (trees.keys - %w[main main2]).first
  pct = ->(t) { format("%+.1f%%", (trees[t] / trees["main"] - 1) * 100) }
  puts format("%-28s main %9.0f  %s %9.0f (%s)  main2 %9.0f (%s)", name, trees["main"], fix, trees[fix], pct.(fix), trees["main2"], pct.("main2"))
end
