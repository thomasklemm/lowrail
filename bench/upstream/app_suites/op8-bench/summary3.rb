# summary3.rb RESULTS.tsv -> per workload: main median Ir per iteration, A/A (ctl vs main), fix6 vs main, spreads
rows = File.readlines(ARGV[0]).map(&:split)
per = ->(r) { r[4].to_f / r[3].to_i }
rows.map { _1[1] }.uniq.each do |w|
  v = ->(t) { rows.select { _1[0] == t && _1[1] == w }.map(&per).sort }
  med = ->(a) { a[a.size / 2] }; sp = ->(a) { (a.max / a.min - 1) * 100 }
  m, c, f = v.("rails-main"), v.("rails-ctl"), v.("rails-fix6")
  puts format("%-9s main %11.0f  A/A %+.2f%%  type-level fix %+.2f%%  (n=%d/%d/%d, spread %.2f/%.2f/%.2f%%)", w, med.(m), (med.(c) / med.(m) - 1) * 100, (med.(f) / med.(m) - 1) * 100, m.size, c.size, f.size, sp.(m), sp.(c), sp.(f))
end
