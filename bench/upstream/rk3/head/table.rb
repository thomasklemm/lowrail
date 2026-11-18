# ruby table.rb RESULTS_TXT: per workload, base = mean of the three main runs, A/A = (max − min) / mean, head's change
# (claimed only above the A/A), objects, and whether every window was JIT-flat; then the cohort gate (A/A ≤ 1.0%,
# no FAIL, every jit 0/0, DONE present).
text = File.read(ARGV[0])
rows = text.lines.grep(/Ir\/op/).map do |l|
  m = l.match(/^(.*) (interp|yjit) (main|head) Ir\/op (\d+) objs\/op ([\d.]+) jit (\S+)/)
  { wl: m[1], side: m[3], ir: m[4].to_i, objs: m[5].to_f, jit: m[6] }
end
int = ->(x) { x.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
worst = 0.0
puts "| Workload | A/A | Main | Head | Change | Objects main → head | JIT-flat |", "| --- | ---: | ---: | ---: | ---: | --- | --- |"
rows.group_by { _1[:wl] }.each do |wl, rs|
  base = rs.select { _1[:side] == "main" }
  head = rs.find { _1[:side] == "head" }
  mean = base.sum { _1[:ir] }.fdiv(base.size)
  aa = (base.map { _1[:ir] }.max - base.map { _1[:ir] }.min) / mean
  worst = [worst, aa].max
  change = head[:ir] / mean - 1
  shown = change.abs > aa ? format("%+.2f%%", change * 100) : format("within A/A (%+.2f%%)", change * 100)
  printf("| %s | %.2f%% | %s | %s | %s | %.1f → %.1f | %s |\n", wl, aa * 100, int.(mean), int.(head[:ir]), shown,
    base.sum { _1[:objs] } / base.size, head[:objs], rs.all? { _1[:jit] == "0/0" } ? "yes" : "no")
end
fails = text.lines.grep(/^FAIL/)
flat = rows.all? { _1[:jit] == "0/0" }
ok = fails.empty? && flat && worst <= 0.01 && text.include?("DONE")
puts "", "Gate: #{ok ? "accepted" : "rejected"} (worst A/A #{format("%.2f%%", worst * 100)}, #{fails.size} failed, " \
  "#{flat ? "every window 0/0" : "a window compiled or invalidated"}#{", incomplete" unless text.include?("DONE")})"
