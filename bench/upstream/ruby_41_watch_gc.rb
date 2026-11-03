# frozen_string_literal: true

# GC over one long window per workload (CENSUS_GC_OPS), two Rubies with an
# A/A pair each. ruby SCRIPT ROOT OLD_A OLD_B NEW_A NEW_B MODE
# Per 1,000 operations: collections (minor/major), GC time, heap page and
# live-slot growth; old-generation malloc growth per operation.
require "json"

root, *labels, mode = ARGV
load_label = lambda do |label|
  Dir[File.join(root, label, "*-#{mode}.json")].sort.flat_map do |file|
    run = JSON.parse(File.read(file))
    run["workloads"].map { [[run["app"], _1["workload"]], _1.fetch("gc_long")] }
  end.to_h
end
runs = labels.map(&load_label)
keys = runs.map(&:keys).reduce(:&)
per_k = ->(g, f) { g[f].to_f * 1000 / g["ops"] }
metrics = { "gc/1k ops" => "count", "minor/1k" => "minor_gc_count", "major/1k" => "major_gc_count",
  "gc ms/1k" => "time", "pages/1k" => "heap_allocated_pages" }
puts "#{keys.size} workloads, #{mode}: sums over all workloads (A, B per Ruby)"
metrics.each do |name, f|
  sums = runs.map { |r| keys.sum { per_k.(r[_1], f) } }
  puts format("  %-10s old %9.1f %9.1f   new %9.1f %9.1f   change %+6.1f%%", name, *sums, 100 * (sums[2] + sums[3] - sums[0] - sums[1]) / (sums[0] + sums[1]))
end
puts "workloads where collections per 1k ops move beyond both A/A spreads:"
keys.each do |k|
  v = runs.map { per_k.(_1[k], "count") }
  aa = [(v[0] - v[1]).abs, (v[2] - v[3]).abs].max
  d = (v[2] + v[3] - v[0] - v[1]) / 2
  next unless d.abs > 2 * aa && d.abs >= 5
  puts format("  %+7.1f gc/1k (old %.1f, aa %.1f) %s", d, (v[0] + v[1]) / 2, aa, k.join(" "))
end
