# summary2.rb BASE.tsv FIX5.tsv -> medians per workload; main/ctl from BASE, fix5 from FIX5
base, f5 = ARGV.map { |f| File.readlines(f).map(&:split) }
per = ->(r) { r[4].to_f / r[3].to_i }
med = ->(rs) { v = rs.map(&per).sort; v[v.size / 2] }
(base + f5).map { _1[1] }.uniq.each do |w|
  m = med.(base.select { _1[0] == "rails-main" && _1[1] == w }); c = med.(base.select { _1[0] == "rails-ctl" && _1[1] == w })
  f1 = med.(base.select { _1[0] == "rails-fix3" && _1[1] == w }); x = f5.select { _1[1] == w }; f = med.(x)
  sp = (x.map(&per).max / x.map(&per).min - 1) * 100
  puts format("%-9s main %11.0f  A/A %+.2f%%  first fix %+.2f%%  freezable? fix %+.2f%% (n=%d, spread %.2f%%)", w, m, (c / m - 1) * 100, (f1 / m - 1) * 100, (f / m - 1) * 100, x.size, sp)
end
