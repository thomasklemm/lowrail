# summary4.rb RESULTS.tsv [EXTRA.tsv] -> per workload: main median Ir per iteration, A/A (ctl vs main), each other tree vs main, spreads
rows = ARGV.flat_map { |f| File.readlines(f).map(&:split) }
per = ->(r) { r[4].to_f / r[3].to_i }
med = ->(a) { a[a.size / 2] }
rows.map { _1[1] }.uniq.each do |w|
  v = ->(t) { rows.select { _1[0] == t && _1[1] == w }.map(&per).sort }
  m = v.("rails-main")
  others = (rows.map { _1[0] }.uniq - ["rails-main"]).filter_map { |t| x = v.(t); "#{t} #{format("%+.2f%%", (med.(x) / med.(m) - 1) * 100)} (n=#{x.size}, spread #{format("%.2f%%", (x.max / x.min - 1) * 100)})" unless x.empty? }
  puts format("%-9s main %11.0f (spread %.2f%%)  ", w, med.(m), (m.max / m.min - 1) * 100) + others.join("  ")
end
