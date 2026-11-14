# frozen_string_literal: true

# Summary of bench/upstream/ce2/walltime output:
#   ruby walltime_summary.rb DIR [BASE]
# Per process and workload: best of N, the fastest window's ms per operation
# (under YJIT only windows that compiled no block; a process with none is left
# out). The raw windows stay in the JSONs.
# Per round: each tree's mean of its two processes over BASE's (default: the
# first tree in meta.json). Per tree, the A/A is process B over process A.
# Reported: the median ratio over rounds with its range, and the mean of the log
# ratios with a 95% t-interval.
require "json"

dir, base = ARGV
abort "usage: walltime_summary.rb DIR [BASE]" unless dir
meta = JSON.parse(File.read(File.join(dir, "meta.json")))
trees = meta.fetch("trees").keys
base ||= trees.first
T95 = { 1 => 12.71, 2 => 4.30, 3 => 3.18, 4 => 2.78, 5 => 2.57, 6 => 2.45, 7 => 2.36, 8 => 2.31, 9 => 2.26, 10 => 2.23,
  11 => 2.20, 12 => 2.18, 13 => 2.16, 14 => 2.14, 15 => 2.13, 19 => 2.09, 29 => 2.05 }.freeze

def median(a) = a.sort[a.size / 2]

def interval(ratios)
  logs = ratios.map { Math.log(_1) }
  n = logs.size
  mean = logs.sum / n
  return [mean, mean, mean].map { Math.exp(_1) } if n < 2
  sd = Math.sqrt(logs.sum { (_1 - mean)**2 } / (n - 1))
  t = T95[n - 1] || T95.select { |k, _| k <= n - 1 }.max_by(&:first).last
  [mean, mean - t * sd / Math.sqrt(n), mean + t * sd / Math.sqrt(n)].map { Math.exp(_1) }
end

pct = ->(r) { format("%+.1f%%", 100 * (r - 1)).sub("-", "−") }
runs = Dir[File.join(dir, "*.json")].reject { File.basename(_1) == "meta.json" }.map do |path|
  app, mode, tree, ab, round = File.basename(path, ".json").match(/\A(.+)-(interpreter|yjit)-(\w+)-([AB])-r(\d+)\z/).captures
  data = JSON.parse(File.read(path))
  per = data["workloads"].to_h do |w|
    windows = w["windows"].select { mode == "interpreter" || _1["blocks"].zero? }
    [w["name"], windows.empty? ? nil : { ms: windows.map { _1["ms_per_op"] }.min, objects: median(windows.map { _1["objects_per_op"] }),
      gc: windows.sum { _1["gc"] }.fdiv(windows.size * w["ops"]) }]
  end
  { app:, mode:, tree:, ab:, round: round.to_i, per: }
end

others = trees - [base]
puts (["| App | Workload | Mode | Rounds | #{base} ms/op (best of N)"] + others.map { "#{_1} / #{base}: median (range); mean [95% CI]" } +
  ["A/A #{trees.join(", ")} (mean)", "objects/op #{trees.join(" → ")} |"]).join(" | ")
puts "| " + (%w[--- --- --- ---: ---:] + others.map { "---" } + %w[--- ---:]).join(" | ") + " |"
runs.group_by { [_1[:app], _1[:mode]] }.sort.each do |(app, mode), rs|
  rs.flat_map { _1[:per].keys }.uniq.each do |name|
    rounds = rs.group_by { _1[:round] }.filter_map do |_, r|
      cell = ->(t, ab) { r.find { _1[:tree] == t && _1[:ab] == ab }&.dig(:per, name) }
      next unless trees.all? { |t| cell.(t, "A") && cell.(t, "B") }
      trees.to_h { |t| [t, { mean: (cell.(t, "A")[:ms] + cell.(t, "B")[:ms]) / 2, aa: cell.(t, "B")[:ms] / cell.(t, "A")[:ms],
        objects: (cell.(t, "A")[:objects] + cell.(t, "B")[:objects]) / 2 }] }
    end
    next if rounds.empty?
    cols = others.map do |t|
      ratios = rounds.map { _1[t][:mean] / _1[base][:mean] }
      mean, lo, hi = interval(ratios)
      "#{pct.(median(ratios))} (#{pct.(ratios.min)} … #{pct.(ratios.max)}); #{pct.(mean)} [#{pct.(lo)}, #{pct.(hi)}]"
    end
    aa = trees.map { |t| pct.(interval(rounds.map { _1[t][:aa] }).first) }.join(", ")
    objects = trees.map { |t| format("%.0f", rounds.sum { _1[t][:objects] } / rounds.size) }.join(" → ")
    puts "| #{app} | #{name} | #{mode == "yjit" ? "YJIT" : "interp"} | #{rounds.size} | " \
      "#{[format("%.2f", rounds.sum { _1[base][:mean] } / rounds.size), *cols, aa, objects].join(" | ")} |"
  end
end
