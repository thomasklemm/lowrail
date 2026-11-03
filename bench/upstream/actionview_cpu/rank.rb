# frozen_string_literal: true

# Ranks frames from profile.rb JSONs across profiles.
#   ruby rank.rb [--filter view|rails|all] [--by selfc|self|total] [--limit N] [--markdown] A.json B.json ...
#   ruby rank.rb --groups A.json ...      # share of samples by framework/area
# Per profile, a frame's share is its samples / the profile's samples:
#   self   samples where the frame is the leaf;
#   selfc  self, with C functions charged to the nearest Ruby frame below them
#          (String#gsub inside html_escape counts for html_escape); GC frames
#          ("(sweeping)", "(marking)") stay on their own;
#   total  samples whose stack contains the frame (once, even if recursive).
# Shares are averaged over the given profiles, so one long profile does not
# dominate; "reach" counts profiles where selfc >= 0.1% or total >= 0.5%.
# "view" keeps actionview/ and the Action Pack/Active Support files on the
# rendering path (url_for and routing, SafeBuffer/ERB::Util, to_query).
require "json"
require "optparse"

opts = { filter: "view", by: "selfc", limit: 40 }
OptionParser.new do |o|
  o.on("--filter F") { opts[:filter] = _1 }
  o.on("--by K") { opts[:by] = _1 }
  o.on("--limit N", Integer) { opts[:limit] = _1 }
  o.on("--markdown") { opts[:markdown] = true }
  o.on("--groups") { opts[:groups] = true }
end.parse!

VIEW_PATH = %r{\ARAILS/(actionview/|actionpack/lib/action_dispatch/(routing|journey|http/url)|actionpack/lib/abstract_controller/(rendering|url_for)|actionpack/lib/action_controller/metal/(rendering|renderers|url_for)|activesupport/lib/active_support/(core_ext/string/output_safety|core_ext/erb/util|html_safe_translation|core_ext/object/to_query))}

def aggregate(p)
  frames = p.fetch("frames")
  key = ->(id) { (f = frames.fetch(id.to_s)) && "#{f[0]} (#{f[1]}#{":#{f[2]}" if f[2]})" }
  file = ->(id) { frames.fetch(id.to_s)[1] }
  ruby = ->(id) { (f = frames.fetch(id.to_s)) && (f[1] != "<cfunc>" || f[0].start_with?("(")) }
  self_c = Hash.new(0); selfc = Hash.new(0); total = Hash.new(0)
  p.fetch("stacks").each do |n, *stack|
    self_c[key.(stack.last)] += n
    selfc[key.(stack.reverse_each.find(&ruby) || stack.last)] += n
    stack.map(&key).uniq.each { total[_1] += n }
  end
  files = p.fetch("frames").values.to_h { |f| ["#{f[0]} (#{f[1]}#{":#{f[2]}" if f[2]})", f[1]] }
  [self_c, selfc, total, files]
end

def group(file, name)
  return "GC (marking, sweeping)" if name.start_with?("(")
  case file
  when %r{\AAPP/app/views/} then "templates (compiled)"
  when %r{\ARAILS/(\w+)/} then $1
  when "<cfunc>" then "C with no Ruby caller"
  when %r{\AGEM/} then "gems"
  when %r{\AAPP/} then "app"
  else "Ruby stdlib/other"
  end
end

profiles = ARGV.map { JSON.parse(File.read(_1)) }
abort "no profiles" if profiles.empty?
labels = profiles.map { _1["label"] }
aggs = profiles.map { aggregate(_1) }

if opts[:groups]
  per = aggs.zip(profiles).map do |(_, selfc, _, files), p|
    g = Hash.new(0)
    selfc.each { |k, n| g[group(files.fetch(k, "<cfunc>"), k)] += n }
    g.transform_values { 100.0 * _1 / p["samples"] }
  end
  names = per.flat_map(&:keys).uniq.sort_by { |k| -per.sum { _1[k] || 0 } }
  puts "| Area (self + C) | #{labels.join(" | ")} |"
  puts "| --- |#{" ---: |" * labels.size}"
  names.each { |k| puts "| #{k} | #{per.map { format("%.1f%%", _1[k] || 0) }.join(" | ")} |" }
  exit
end

keep = lambda do |f|
  case opts[:filter]
  when "view" then f.match?(VIEW_PATH)
  when "rails" then f.start_with?("RAILS/")
  else true
  end
end
table = Hash.new { |h, k| h[k] = { "self" => [], "selfc" => [], "total" => [] } }
aggs.each_with_index do |(s, sc, t, files), i|
  n = profiles[i]["samples"].to_f
  t.each_key do |k|
    next unless keep.(files.fetch(k, "<cfunc>"))
    table[k]["self"][i] = s[k] / n
    table[k]["selfc"][i] = sc[k] / n
    table[k]["total"][i] = t[k] / n
  end
end
mean = ->(a) { profiles.size.times.sum { a[_1] || 0.0 } / profiles.size }
rows = table.map do |k, v|
  { key: k, self: mean.(v["self"]), selfc: mean.(v["selfc"]), total: mean.(v["total"]),
    reach: profiles.size.times.count { (v["selfc"][_1] || 0) >= 0.001 || (v["total"][_1] || 0) >= 0.005 },
    per: profiles.size.times.map { 100 * (v[opts[:by]][_1] || 0) } }
end
rows.sort_by! { -_1[opts[:by].to_sym] }
if opts[:markdown]
  puts "| Frame | self % | self+C % | total % | reach | #{labels.join(" | ")} |"
  puts "| --- | ---: | ---: | ---: | ---: |#{" ---: |" * labels.size}"
  rows.first(opts[:limit]).each do |r|
    puts "| `#{r[:key].sub(%r{ \(RAILS/}, " (")}` | #{format("%.2f", 100 * r[:self])} | #{format("%.2f", 100 * r[:selfc])} | " \
      "#{format("%.1f", 100 * r[:total])} | #{r[:reach]}/#{labels.size} | #{r[:per].map { format("%.1f", _1) }.join(" | ")} |"
  end
else
  puts "profiles: #{labels.join(", ")} (columns: self+C, self, total %, reach; then #{opts[:by]} per profile)"
  rows.first(opts[:limit]).each do |r|
    puts format("%6.2f %6.2f %6.1f %2d  %s  [%s]", 100 * r[:selfc], 100 * r[:self], 100 * r[:total], r[:reach], r[:key],
      r[:per].map { format("%.1f", _1) }.join(" "))
  end
end
