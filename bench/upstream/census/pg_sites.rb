# frozen_string_literal: true

# PG census view of a census label (docs/upstream/pg-census.md):
#   ruby SCRIPT OUT LABEL [MODE] [LIMIT]
# Ranks Rails lines by breadth across the PostgreSQL runs only (census 4's
# rule, CensusRank), splits them into PG-adapter families and general lines,
# lists pg-gem lines, prices the type-map dispatch per app, and compares each
# APP-nops run (prepared statements off) with APP on the PG families.
require_relative "rank"

out, label, mode, limit = ARGV[0], ARGV[1], ARGV[2] || "interpreter", Integer(ARGV[3] || 30)
runs = CensusRank.load_runs(File.join(out, label), mode).select { _1["adapter"] == "postgresql" }
abort "no postgresql #{mode} runs for #{label}" if runs.empty?
base, nops = runs.partition { !_1["app"].end_with?("-nops") }

FAMILIES = [
  ["type map", %r{\Aactiverecord/lib/active_record/type/hash_lookup_type_map\.rb|postgresql_adapter\.rb:(104[4-9]|105\d)\z}],
  ["OID decoding", %r{\Aactiverecord/lib/active_record/connection_adapters/postgresql/oid/}],
  ["quoting", %r{\Aactiverecord/lib/active_record/connection_adapters/postgresql/quoting\.rb}],
  ["statements/exec_params", %r{\Aactiverecord/lib/active_record/connection_adapters/postgresql/database_statements\.rb}],
  ["other PG adapter", %r{\Aactiverecord/lib/active_record/connection_adapters/postgresql(_adapter\.rb|/)}],
  ["Arel PG visitor", %r{\Aactiverecord/lib/arel/visitors/postgresql\.rb}],
].freeze
family = ->(site) { FAMILIES.find { site.match?(_2) }&.first }

rows = CensusRank.rows(base, tiers: [7, 5, 3, 2])
apps = base.map { CensusRank.app_of(_1["app"]) }.uniq.sort
workloads = base.sum { _1["workloads"].size }
puts "#{label} #{mode}: #{apps.size} PG apps (#{apps.join(", ")}), #{workloads} workloads"
short = ->(site) { site.sub("activerecord/lib/active_record/connection_adapters/", "AR/adapters/").sub(%r{\A(\w+)/lib/(\w+/)?}, "\\1/") }
fmt = ->(i, r) { format("%3d %-64s apps %d share %3.0f%% mean %6.2f  %s", i, short.(r[:site]), r[:apps], r[:share] * 100, r[:mean], r[:classes].first(3).join(",")) }

puts "\n== PG-adapter lines, by breadth"
rows.select { family.(_1[:site]) }.first(limit).each_with_index { |r, i| puts "#{fmt.(i + 1, r)}  [#{family.(r[:site])}]" }
puts "\n== General lines, by breadth"
rows.reject { family.(_1[:site]) }.first(limit).each_with_index { |r, i| puts fmt.(i + 1, r) }

puts "\n== Family totals (mean objects/op over all PG workloads; apps reached by any line)"
FAMILIES.map(&:first).each do |name|
  fam = rows.select { family.(_1[:site]) == name }
  reached = fam.flat_map { _1[:app_names] }.uniq
  puts format("  %-24s lines %3d  mean %6.2f  apps %d", name, fam.size, fam.sum { _1[:mean] }, reached.size)
end

puts "\n== pg gem lines (GEM/pg-*), mean objects/op"
pg = Hash.new(0.0)
base.each { |run| run["workloads"].each { |w| w["sites"].each { |s| pg["#{s["file"].sub(%r{\AGEM/(4\.0\.0/)?(bundler/)?gems/}, "")}:#{s["line"]} #{s["class"]}"] += s["objects_per_op"] if s["file"].match?(%r{/pg-\d}) } } }
pg.sort_by { -_2 }.first(10).each { |k, v| puts format("  %7.2f  %s", v / workloads, k) }

median = ->(a) { a.empty? ? 0.0 : a.sort[a.size / 2] }
per_app = ->(run_set, pattern) do
  run_set.to_h do |run|
    vals = run["workloads"].map { |w| w["sites"].select { "#{_1["file"]}:#{_1["line"]}".match?(pattern) }.sum { _1["objects_per_op"] } }
    [run["app"], [median.(vals), vals.sum / vals.size, vals.max]]
  end
end
type_map = %r{RAILS/activerecord/lib/active_record/(type/hash_lookup_type_map\.rb|connection_adapters/postgresql_adapter\.rb:1047\z)}
puts "\n== Type-map dispatch (postgresql_adapter.rb:1047 + hash_lookup_type_map.rb): objects/op median, mean, max per app"
per_app.(runs, type_map).sort.each { |app, (med, mean, max)| puts format("  %-16s median %5.1f  mean %5.1f  max %6.1f", app, med, mean, max) }

unless nops.empty?
  puts "\n== prepared_statements: false (APP-nops - APP), median per workload: total and PG-adapter families"
  pg_line = ->(s) { s["file"].start_with?("RAILS/") && family.(s["file"].delete_prefix("RAILS/") + ":#{s["line"]}") }
  nops.each do |off|
    on = base.find { _1["app"] == off["app"].delete_suffix("-nops") } or next
    by = ->(run) { run["workloads"].to_h { |w| [w["workload"], w] } }
    a, b = by.(on), by.(off)
    total = b.keys.map { |k| median.(b[k]["gc_enabled_objects_per_op"]) - median.(a[k]["gc_enabled_objects_per_op"]) }
    fam = b.keys.map { |k| b[k]["sites"].select(&pg_line).sum { _1["objects_per_op"] } - a[k]["sites"].select(&pg_line).sum { _1["objects_per_op"] } }
    puts format("  %-16s total %+7.1f  PG families %+7.1f  (%d workloads)", off["app"], median.(total), median.(fam), total.size)
  end
end
