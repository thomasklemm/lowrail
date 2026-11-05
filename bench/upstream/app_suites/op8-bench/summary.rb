# summary.rb results-*.tsv -> per Ruby and workload: median Ir per iteration for each tree, A/A (ctl vs main) and fix vs main
ARGV.each do |f|
  rows = File.readlines(f).map(&:split)
  puts "== #{File.basename(f, ".tsv")}"
  rows.group_by { _1[1] }.each do |w, rs|
    med = rs.group_by { _1[0] }.transform_values { |x| v = x.map { |r| r[4].to_f / r[3].to_i }.sort; v[v.size / 2] }
    spread = rs.group_by { _1[0] }.transform_values { |x| v = x.map { |r| r[4].to_f / r[3].to_i }; (v.max - v.min) / v.min * 100 }
    aa = (med["rails-ctl"] / med["rails-main"] - 1) * 100
    fx = (med["rails-fix3"] / med["rails-main"] - 1) * 100
    puts format("%-9s main %10.0f  ctl %10.0f  fix %10.0f  A/A %+.2f%%  fix %+.2f%%  (rep spread main %.2f%% ctl %.2f%% fix %.2f%%, n=%d)",
      w, med["rails-main"], med["rails-ctl"], med["rails-fix3"], aa, fx, spread["rails-main"], spread["rails-ctl"], spread["rails-fix3"], rs.size / 3)
  end
end
