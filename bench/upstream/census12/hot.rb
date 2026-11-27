# frozen_string_literal: true

# Census 12 hot list: Rails methods (or lines) by their share of each whole
# workload's instructions, on one label.
#   ruby hot.rb DIR LABEL MODE method|line [--limit N]
# Per site: mean share over all workloads (share of each workload's own Ir/op,
# averaged), the max share and where, reach (workloads where it costs >= 0.1%),
# and score = mean share x reach / total workloads. Self cost; a line's cost
# includes the C functions it calls (cpu_harness's attribution).
require "json"

dir, label, mode, by = ARGV.first(4)
limit = (i = ARGV.index("--limit")) ? Integer(ARGV[i + 1]) : 40
workloads = Dir["#{dir}/#{label}/*-#{mode}.json"].sort.flat_map do |path|
  run = JSON.parse(File.read(path))
  run["workloads"].select { _1.fetch("jit_flat", true) }.map { [run["app"], _1] }
end
n = workloads.size
sites = Hash.new { |h, k| h[k] = {} }
workloads.each do |app, w|
  entries = by == "method" ? w["methods"].map { ["#{_1["file"]} #{_1["method"]}", _1["self_ir_per_op"]] } :
    w["sites"].map { ["#{_1["file"]}:#{_1["line"]} #{_1["method"]}", _1["ir_per_op"]] }
  entries.each do |key, ir|
    next unless key.start_with?("RAILS/")
    sites[key]["#{app} #{w["workload"]}"] = (sites[key]["#{app} #{w["workload"]}"] || 0) + ir / w["ir_per_op"]
  end
end
rows = sites.map do |key, per|
  mean = per.values.sum / n
  reach = per.count { _2 >= 0.001 }
  max_w, max = per.max_by { _2 }
  apps = per.select { _2 >= 0.001 }.keys.map { _1.split(" ", 2)[0] }.uniq.size
  [key.delete_prefix("RAILS/"), mean, reach, apps, max, max_w, mean * reach / n]
end
puts "# #{label} #{mode} by #{by}: #{n} workloads; mean share, reach (workloads >= 0.1%), apps, max share, score = mean x reach/#{n}"
rows.sort_by { -_7 }.first(limit).each_with_index do |(key, mean, reach, apps, max, max_w, score), i|
  printf("%3d %6.3f%% reach %2d/%d apps %d max %6.3f%% (%s) score %.3f  %s\n", i + 1, 100 * mean, reach, n, apps, 100 * max, max_w[0, 45], 100 * score, key)
end
