# frozen_string_literal: true

# Allocation sites per request from allocs.rb runs: mean over each app's
# workloads, then over apps (each app weighs the same), ranked by objects or
# by bytes. A site reaches an app at >= 1 object per request.
#   ruby alloc_report.rb [--by objects|bytes] [--top N] FILE.json...
require "json"

by = ARGV.include?("--by") ? ARGV[ARGV.index("--by") + 1] : "objects"
top = ARGV.include?("--top") ? Integer(ARGV[ARGV.index("--top") + 1]) : 40
files = ARGV.select { _1.end_with?(".json") }
SHORT = %r{\A.*/(gems|bundler/gems)/|\A.*/\.corpus/[^/]+/}

apps = {}
files.each do |path|
  j = JSON.parse(File.read(path))
  name = (File.basename(path).start_with?("ce2-") ? "CE2 " : "") + j["app"]
  w = j["windows"]
  sites = Hash.new { |h, k| h[k] = [0.0, 0.0, Hash.new(0.0)] }
  w.each do |x|
    x["sites"].each do |site, n, bytes, classes|
      s = sites[site.sub(SHORT, "")]
      s[0] += n / w.size
      s[1] += bytes / w.size
      classes.each { |c, m| s[2][c] += m / w.size }
    end
  end
  apps[name] = { sites: sites, objects: w.sum { _1["objects_per_request"] } / w.size,
    bytes: w.sum { _1["bytes_per_request"] } / w.size }
end
names = apps.keys
idx = by == "bytes" ? 1 : 0
puts "per request: " + names.map { |a| format("%s %.0f objects %.0f KB", a, apps[a][:objects], apps[a][:bytes] / 1024) }.join("; ")
keys = apps.values.flat_map { _1[:sites].keys }.uniq
rows = keys.map do |k|
  vals = names.map { apps[_1][:sites].key?(k) ? apps[_1][:sites][k] : [0, 0, {}] }
  share = names.each_index.sum { |i| vals[i][idx] / (idx == 0 ? apps[names[i]][:objects] : apps[names[i]][:bytes]) } / names.size
  [k, vals, share, vals.count { _1[0] >= 1 }]
end
puts (["share", "apps"] + names + ["site", "classes"]).join("\t")
rows.sort_by { -_3 }.first(top).each do |k, vals, share, reach|
  classes = vals.flat_map { _1[2].to_a }.group_by(&:first).transform_values { |v| v.sum(&:last) }.sort_by { -_2 }.first(2).map(&:first).join(",")
  cells = vals.map { |v| idx == 0 ? v[0].round(1) : (v[1] / 1024).round(1) }
  puts ([format("%.2f%%", 100 * share), reach] + cells + [k, classes]).join("\t")
end
