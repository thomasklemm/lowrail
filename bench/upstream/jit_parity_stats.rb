# frozen_string_literal: true

# JIT parity census: rank --yjit-stats / --zjit-stats exit and fallback
# reasons across apps. ruby SCRIPT DIR yjit|zjit [LIMIT]
# DIR holds rails_main_census_4.rb `stats` JSONs (APP-MODE.json): counters
# after warming every workload, for 20 operations of each. Values are per
# operation; a reason "reaches" an app at >= 1 per operation.
require "json"

dir, mode = ARGV[0], ARGV[1]
limit = Integer(ARGV[2] || 30)
runs = Dir["#{dir}/*-#{mode}.json"].sort.map { JSON.parse(File.read(_1)) }
abort "no runs" if runs.empty?
app_of = ->(name) { name.sub(/-mysql\z/, "") }

reason = if mode == "yjit"
  # Fallback reasons (send_*, invokeblock_*, ...) and side exits (exit_*).
  ->(key) { key.match?(/\A(send|invokesuper|invokeblock|getivar|setivar|definedivar|expandarray|objtostring|opt|oaref|gbpp|exit)_/) &&
    !key.match?(/_(count|bytes|size|ns)\z/) && key != "exit_from_branch_stub" }
else
  ->(key) { key.match?(/\A(send_fallback|exit|complex_arg_pass|unspecialized_send_def_type|uncategorized_fallback|invokeblock_handler|dynamic_)/) &&
    !key.match?(/_(count|bytes|size|ns|time)\z/) }
end

totals = Hash.new { |h, k| h[k] = {} }
runs.each do |run|
  run["stats"].each do |key, value|
    next unless reason.(key)
    totals[key][run["app"]] = value.fdiv(run["ops"])
  end
end
summary = { "side exits" => %w[side_exit_count total_exit_count], "dynamic sends" => %w[num_send_dynamic dynamic_send_count] }
summary.each do |label, keys|
  values = runs.map { |run| keys.filter_map { run["stats"][_1] }.first.to_f / run["ops"] }
  puts format("%-14s per op: %s", label, runs.zip(values).map { |r, v| "#{r["app"]} #{v.round(0)}" }.join(", "))
end
rows = totals.map do |key, per_app|
  apps = per_app.select { |_, v| v >= 1 }.keys.map(&app_of).uniq
  { key: key, apps: apps.size, mean: per_app.values.sum / runs.size, max_app: per_app.max_by(&:last)&.first }
end
rows.sort_by { [-(_1[:apps] >= 7 ? 1 : 0), -_1[:mean]] }.first(limit).each_with_index do |r, i|
  puts format("%3d %-58s apps %2d mean/op %9.1f top %s", i + 1, r[:key], r[:apps], r[:mean], r[:max_app])
end
