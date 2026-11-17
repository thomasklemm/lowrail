# best.rb FILE: best and median i/s per tree and case from rounds.sh output, each tree against main.
rounds = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
File.foreach(ARGV[0]) do |line|
  next unless line =~ /\A(\S+) r\d+: +(.+?) +([\d.]+)([kM]?) \(/
  rounds[$2][$1] << $3.to_f * { "k" => 1e3, "M" => 1e6, "" => 1 }.fetch($4)
end
rounds.each do |name, trees|
  best = trees.transform_values(&:max)
  med = trees.transform_values { |v| s = v.sort; s[s.size / 2] }
  puts name
  trees.each_key do |t|
    puts format("  %-6s best %9.0f (%+6.1f%%)  median %9.0f (%+6.1f%%)  min %9.0f  n=%d", t, best[t], (best[t] / best["main"] - 1) * 100, med[t], (med[t] / med["main"] - 1) * 100, trees[t].min, trees[t].size)
  end
end
