# rank.rb NAME=report.json ...: lines outside the app (not dev/test work) by share of request
# allocations, averaged across apps. Lines are matched across apps by file, method and source
# text, so the same Rails line at another line number (7.2 / 8.0 / 8.1) counts as one.
require "json"

apps = ARGV.map { _1.split("=", 3) }
# Each app's `bundle list --paths`, to read a line's source and method from the version it runs.
def resolve(paths, site)
  file, line = site.match(/\A(.+):(\d+)\z/).captures
  path = case file
  when %r{\ARAILS/(\w+)/(.+)\z} then paths.find { File.basename(_1).match?(/\A#{$1}-\d/) }&.then { File.join(_1, $2) }
  when %r{\AGEM/([^/]+)/(.+)\z} then paths.find { File.basename(_1).match?(/\A#{Regexp.escape($1)}-(\d|\h{12}\z)/) }&.then { File.join(_1, $2) }
  when %r{\ARUBY/(?!<)(.+)\z}
    rel = $1
    paths.find { _1.include?("/lib/ruby/gems/") }&.then { File.join(_1[%r{\A.+/lib/ruby/}], _1[%r{/lib/ruby/gems/([^/]+)/}, 1], rel) }
  end
  return [nil, nil] unless path && File.exist?(path)
  lines = File.readlines(path, chomp: true).map(&:scrub)
  text = lines[line.to_i - 1]&.strip
  method = lines[0, line.to_i].reverse_each.lazy.map { _1[/^\s*def\s+(?:self\.)?([^\s(;=]+=?)/, 1] }.find(&:itself)
  [method, text]
end
rows = Hash.new { |h, k| h[k] = { shares: {}, sites: {} } }
apps.each do |name, path, list|
  j = JSON.parse(File.read(path))
  paths = File.readlines(list, chomp: true)
  per_request = j["summary"].sum { _1["objects_per_request"] } / j["summary"].size
  next if per_request.zero?
  j["ranked"].each do |r|
    next if r["mode"]
    file = r["site"].sub(/:\d+\z/, "")
    method, text = resolve(paths, r["site"])
    key = [file, method, text || r["site"]]
    all = r["all"].sum / r["all"].size
    rows[key][:shares][name] = (rows[key][:shares][name] || 0) + all / per_request
    rows[key][:sites][name] = r["site"]
  end
end
names = apps.map(&:first)
ranked = rows.map { |k, v| [k, v, v[:shares].values.sum / names.size] }.sort_by { -_3 }
limit = Integer(ENV.fetch("TOP", "40"))
puts "| # | Line | Method | Mean share | Apps ≥ 0.5% | #{names.join(" | ")} | Source |"
puts "| ---: | --- | --- | ---: | ---: | #{names.map { "---:" }.join(" | ")} | --- |"
ranked.first(limit).each_with_index do |(k, v, mean), i|
  cells = names.map { v[:shares][_1] ? format("%.2f%%", 100 * v[:shares][_1]) : "" }
  wide = v[:shares].count { _2 >= 0.005 }
  site = v[:sites].values.first
  puts "| #{i + 1} | `#{site}` | `#{k[1]}` | #{format("%.2f%%", 100 * mean)} | #{wide} | #{cells.join(" | ")} | `#{k[2].to_s[0, 70].gsub("|", "\\|")}` |"
end
