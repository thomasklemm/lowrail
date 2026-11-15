# Best of N per setting from ips_matrix.sh output, against none/on/0:
#   ruby ips_best.rb ips-*.txt
best = Hash.new { |h, k| h[k] = [] }
label = nil
ARGF.each_line do |l|
  if l =~ /^=== \S+ \S+ .* (\S+\/\S+\/\S+(?: aa)?) round (\d+)/ then label = $1
  elsif l =~ /([\d.]+)\s+\(±\s*([\d.]+)%\) i\/s/ then best[label] << [$1.to_f, $2.to_f]
  end
end
base = best["none/on/0"].map(&:first).max
best.each { |k, v| b = v.map(&:first).max; printf("%-20s best %8.1f i/s  %+6.1f%%  rounds %s\n", k, b, 100.0 * (b - base) / base, v.map { "%.1f±%.0f%%" % _1 }.join(" ")) }
