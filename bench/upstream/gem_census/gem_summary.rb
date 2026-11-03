# frozen_string_literal: true

# Per-gem totals for docs/upstream/gem-census.md: ruby gem_summary.rb OUT LABEL MODE [LIMIT]
# For every gem (Ruby's default gems and the harness's rack-test excluded, as in
# `rank --gem all`): apps whose workloads allocate >= 0.5 objects per operation in
# its lines, the mean objects per operation over all workloads, its share of all
# allocations, the versions seen and its largest line.
require "json"
require_relative "../census/rank"

out, label, mode, limit = ARGV
runs = CensusRank.load_runs(File.join(out, label), mode)
workloads = runs.flat_map { |run| run["workloads"].map { [run["app"], _1] } }
total = workloads.size
all_objects = 0.0
gems = Hash.new { |h, k| h[k] = { per: Hash.new(0.0), lines: Hash.new(0.0), versions: {} } }
workloads.each do |app, w|
  w["sites"].each do |s|
    all_objects += s["objects_per_op"]
    key, = CensusRank::ALL_GEMS.(s["file"], s["line"])
    next unless key
    m = s["file"].match(CensusRank::GEM_PATH)
    g = gems[m[2]]
    g[:per][[app, w["workload"]]] += s["objects_per_op"]
    g[:lines][key[/\A[^:]+:/] + s["line"].to_s] += s["objects_per_op"]
    g[:versions][m[3]] = true
  end
end
rows = gems.map do |name, g|
  apps = g[:per].select { _2 >= CensusRank::REACH }.keys.map { CensusRank.app_of(_1[0]) }.uniq
  { name:, apps: apps.size, mean: g[:per].values.sum / total, share: g[:per].values.sum / all_objects,
    versions: g[:versions].keys.sort, top: g[:lines].max_by { _2 } }
end
puts "#{runs.size} runs, #{runs.map { CensusRank.app_of(_1["app"]) }.uniq.size} apps, #{total} workloads (#{mode}); " \
  "all sites: #{(all_objects / total).round(1)} objects per operation"
puts "| Gem | Apps | Objects/op | Share of all | Versions | Largest line (objects/op) |"
puts "| --- | ---: | ---: | ---: | --- | --- |"
rows.sort_by { [-_1[:apps], -_1[:mean]] }.first(Integer(limit || 40)).each do |r|
  puts format("| %s | %d | %.1f | %.2f%% | %s | `%s` (%.1f) |", r[:name], r[:apps], r[:mean], r[:share] * 100,
    r[:versions].join(", "), r[:top][0], r[:top][1] / total)
end
