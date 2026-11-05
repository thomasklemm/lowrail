# win.rb LOG BASE  -> per-iteration window (long - short)/3 per bench/variant, % vs BASE
h = Hash.new { |x, k| x[k] = {} }
File.readlines(ARGV[0]).each { |l| next unless l =~ /^\w+-([\w-]+?)-interpreter-(.+)-(1|4): ([\d,]+)/; h[[$1, $2]][$3] = $4.delete(",").to_i }
w = h.transform_values { |v| v["4"] && v["1"] ? (v["4"] - v["1"]) / 3.0 : nil }
base = ARGV[1] || "m"
w.keys.map(&:first).uniq.each { |b| bb = w[[b, base]]; next unless bb; w.select { |k, _| k[0] == b }.sort.each { |(_, v), x| next unless x; printf("%-11s %-8s %.5e %+.3f%%\n", b, v, x, (x / bb - 1) * 100) } }
