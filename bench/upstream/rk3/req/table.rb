# ruby table.rb BATCH_OUTPUT: per workload, base = mean of the none.rb runs, A/A = their spread, RK3 and RK3+RK4 change.
rows = File.readlines(ARGV[0]).grep(/Ir\/op/).map do |l|
  m = l.match(/^(.*) (interp|yjit) (\S+) Ir\/op (\d+) objs\/op ([\d.]+) jit (\S+)/)
  {wl: m[1], patch: m[3], ir: m[4].to_i, objs: m[5].to_f, jit: m[6]}
end
puts "| Workload | A/A | Base | RK3 | RK3+RK4 | Objects base → both | JIT-flat |", "| --- | ---: | ---: | ---: | ---: | --- | --- |"
rows.group_by { _1[:wl] }.each do |wl, rs|
  base = rs.select { _1[:patch] == "none.rb" }
  mean = base.sum { _1[:ir] }.fdiv(base.size)
  aa = (base.map { _1[:ir] }.max - base.map { _1[:ir] }.min) / mean * 100
  one = ->(p) { r = rs.find { _1[:patch] == p }; format("%+.2f%%", (r[:ir] / mean - 1) * 100) }
  both = rs.find { _1[:patch] == "rk34.rb" }
  flat = rs.all? { _1[:jit] == "0/0" } ? "yes" : "no"
  printf("| %s | %.2f%% | %s | %s | %s | %.1f → %.1f | %s |\n", wl, aa, mean.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse,
    one.("rk3.rb"), one.("rk34.rb"), base.sum { _1[:objs] } / base.size, both[:objs], flat)
end
