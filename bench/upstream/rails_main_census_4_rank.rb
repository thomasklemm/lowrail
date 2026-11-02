# frozen_string_literal: true

# Census 4 ranking: breadth first. ruby SCRIPT DIR [MODE] [LIMIT] [--tsv]
# A Rails source line "reaches" a workload when it allocates >= 0.5 objects per
# operation there. Apps are counted once (fizzy and fizzy-mysql are one app).
# Tiers: apps reached (>= 7, 5-6, 3-4, 2, 1). Within a tier, rank by the mean
# objects per operation over every workload of every app (per-call cost times
# how often an ordinary operation reaches the line).
require "json"

dir, mode, limit, tsv = ARGV[0], ARGV[1] || "interpreter", Integer(ARGV[2] || 60), ARGV.include?("--tsv")
runs = Dir["#{dir}/*-#{mode}.json"].sort.map { JSON.parse(File.read(_1)) }
abort "no runs in #{dir}" if runs.empty?
app_of = ->(name) { name.sub(/-mysql\z/, "") }
workloads = runs.flat_map { |run| run["workloads"].map { [run["app"], _1] } }
total = workloads.size
sites = Hash.new { |h, k| h[k] = { per_workload: Hash.new(0.0), classes: Hash.new(0.0) } }
workloads.each do |app, w|
  w["sites"].each do |s|
    next unless s["file"].start_with?("RAILS/")
    key = "#{s["file"].delete_prefix("RAILS/")}:#{s["line"]}"
    sites[key][:per_workload][[app, w["workload"], w["kind"]]] += s["objects_per_op"]
    sites[key][:classes][s["class"]] += s["objects_per_op"]
  end
end
tier = ->(apps) { apps >= 7 ? 0 : apps >= 5 ? 1 : apps >= 3 ? 2 : apps == 2 ? 3 : 4 }
rows = sites.map do |key, data|
  hit = data[:per_workload].select { |_, v| v >= 0.5 }
  apps = hit.keys.map { app_of.(_1[0]) }.uniq
  kinds = hit.keys.map { _1[2] }.uniq.sort
  mean = data[:per_workload].values.sum / total
  { site: key, apps: apps.size, app_names: apps.sort, share: hit.size.fdiv(total), kinds: kinds, mean: mean,
    classes: data[:classes].sort_by { -_2 }.first(2).map(&:first) }
end
rows = rows.select { _1[:apps] > 0 }.sort_by { [tier.(_1[:apps]), -_1[:mean]] }
if tsv
  puts %w[rank site apps share mean_objects_per_op kinds classes app_names].join("\t")
  rows.each_with_index { |r, i| puts [i + 1, r[:site], r[:apps], r[:share].round(3), r[:mean].round(2), r[:kinds].join(","), r[:classes].join(","), r[:app_names].join(",")].join("\t") }
else
  puts "#{runs.size} runs, #{runs.map { app_of.(_1["app"]) }.uniq.size} apps, #{total} workloads (#{mode})"
  rows.first(limit).each_with_index do |r, i|
    puts format("%3d %-78s apps %d share %4.0f%% mean %6.2f %-22s %s", i + 1, r[:site][0, 78], r[:apps], r[:share] * 100, r[:mean], r[:kinds].join(","), r[:classes].join(","))
  end
end
