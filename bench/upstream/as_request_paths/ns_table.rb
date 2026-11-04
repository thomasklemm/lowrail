# ruby ns_table.rb OUT/ns.tsv -> medians per case/mode: main, A/A change, candidate change
rows = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
File.foreach(ARGV[0]) { |l| c, m, v, _, ns = l.split("\t"); rows[[c, m]][v] << ns.to_f }
med = ->(a) { s = a.sort; n = s.size; n.odd? ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2 }
rows.each do |(c, m), v|
  a, aa, b = med.(v["main"]), med.(v["aa"]), med.(v["cand"])
  printf "%-22s %-4s main %9.1f ns  A/A %+5.1f%%  cand %9.1f ns  %+6.1f%%  (n=%d)\n", c, m, a, (aa / a - 1) * 100, b, (b / a - 1) * 100, v["main"].size
end
