# frozen_string_literal: true

# cpu_cells.rb DIR BASE HEAD HEAD2 : whole-workload Ir per op of script/cpu-census labels
# (interpreter, JIT-flat in all three), HEAD against BASE per workload, with HEAD's A/A
# (HEAD2 against HEAD) next to it; then per app the median change and the A/A median |Δ|,
# and over all workloads the median and the count beyond ±1%.
require "json"
dir, base, head, head2 = ARGV
load = lambda do |label|
  Dir[File.join(dir, label, "*-interpreter.json")].each_with_object({}) do |path, h|
    run = JSON.parse(File.read(path))
    run["workloads"].each { |w| h[[run["app"], w["workload"]]] = w["ir_per_op"] if w.fetch("jit_flat", true) }
  end
end
b, h, h2 = load.(base), load.(head), load.(head2)
keys = (b.keys & h.keys & h2.keys).sort
med = ->(a) { s = a.sort; s.empty? ? 0 : (s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0) }
rows = keys.map { |k| [k, (h[k] / b[k] - 1) * 100, (h2[k] / h[k] - 1) * 100] }
rows.each { |(app, wl), d, aa| puts format("%-18s %-44s %+7.2f%%  A/A %+6.2f%%", app, wl, d, aa) }
puts
puts "| App | Workloads | Median #{head} vs #{base} | Range | A/A median \\|Δ\\| |"
puts "| --- | ---: | ---: | --- | ---: |"
rows.group_by { _1[0][0] }.sort.each do |app, rs|
  ds = rs.map { _2 }
  puts format("| %s | %d | %+.2f%% | %+.2f%% … %+.2f%% | %.2f%% |", app, rs.size, med.(ds), ds.min, ds.max, med.(rs.map { _3.abs }))
end
ds = rows.map { _2 }
puts format("All %d workloads: median %+.2f%%; %d faster and %d slower beyond 1%%; A/A median |Δ| %.2f%%",
  rows.size, med.(ds), ds.count { _1 < -1 }, ds.count { _1 > 1 }, med.(rows.map { _3.abs }))
rows.select { _2 > 1 }.each { |(app, wl), d, aa| puts format("slower: %s %s %+.2f%% (A/A %+.2f%%)", app, wl, d, aa) }
