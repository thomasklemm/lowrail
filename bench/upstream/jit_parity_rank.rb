# frozen_string_literal: true

# JIT parity census: per-site allocation differences, JIT minus interpreter.
#   ruby SCRIPT DIR yjit|zjit [LIMIT] [--tsv] [--control DIR2]
# DIR holds rails_main_census_4.rb profile JSONs (APP-MODE.json). A site is
# FILE:LINE (any file: Rails, gems, app, Ruby). It "reaches" a workload when
# the JIT allocates >= 0.5 more objects per operation there than the
# interpreter. Sites are tiered by apps reached (>= 7, 5-6, 3-4, 2, 1), then
# ranked by the mean extra objects per operation over all workloads. Negative
# sites (the JIT allocates less, usually an attribution shift such as
# <internal:array>) are listed separately. With --control, the same is
# computed for DIR2's interpreter run against DIR's interpreter run (A/A).
require "json"

dir, mode = ARGV[0], ARGV[1]
limit = Integer(ARGV[2] =~ /\A\d+\z/ ? ARGV[2] : 40)
tsv = ARGV.include?("--tsv")
control = ARGV[ARGV.index("--control") + 1] if ARGV.include?("--control")
app_of = ->(name) { name.sub(/-mysql\z/, "") }

load_runs = ->(d, m) {
  Dir["#{d}/*-#{m}.json"].sort.to_h do |path|
    run = JSON.parse(File.read(path))
    [run["app"], run["workloads"].to_h { [_1["workload"], _1] }]
  end
}

def sites_of(workload)
  workload["sites"].each_with_object(Hash.new(0.0)) do |s, h|
    h["#{s["file"]}:#{s["line"]}"] += s["objects_per_op"]
  end
end

def classes_of(workload)
  workload["sites"].each_with_object(Hash.new { |h, k| h[k] = Hash.new(0.0) }) do |s, h|
    h["#{s["file"]}:#{s["line"]}"][s["class"]] += s["objects_per_op"]
  end
end

def median(values) = values.sort[values.size / 2]

base = load_runs.(dir, "interpreter")
other = control ? load_runs.(control, "interpreter") : load_runs.(dir, mode)
abort "no runs" if base.empty? || other.empty?
pairs = base.flat_map do |app, workloads|
  workloads.filter_map { |name, w| (o = other.dig(app, name)) && [app, name, w, o] }
end
total = pairs.size
per_site = Hash.new { |h, k| h[k] = { diffs: {}, classes: Hash.new(0.0) } }
totals = []
pairs.each do |app, name, w, o|
  a, b = sites_of(w), sites_of(o)
  cb = classes_of(o)
  (a.keys | b.keys).each do |site|
    d = b[site] - a[site]
    next if d.abs < 0.05
    per_site[site][:diffs][[app, name]] = d
    cb[site].each { |k, v| per_site[site][:classes][k] += v } if d > 0
  end
  totals << [app, name, median(o["gc_enabled_objects_per_op"]) - median(w["gc_enabled_objects_per_op"])]
end

tier = ->(apps) { apps >= 7 ? 0 : apps >= 5 ? 1 : apps >= 3 ? 2 : apps == 2 ? 3 : 4 }
rows = per_site.map do |site, data|
  hit = data[:diffs].select { |_, v| v >= 0.5 }
  lost = data[:diffs].select { |_, v| v <= -0.5 }
  { site: site, apps: hit.keys.map { app_of.(_1[0]) }.uniq.size, workloads: hit.size,
    neg_apps: lost.keys.map { app_of.(_1[0]) }.uniq.size, neg_workloads: lost.size,
    mean: data[:diffs].values.sum / total, classes: data[:classes].sort_by { -_2 }.first(2).map(&:first),
    app_names: hit.keys.map { app_of.(_1[0]) }.uniq.sort }
end
positive = rows.select { _1[:apps] > 0 }.sort_by { [tier.(_1[:apps]), -_1[:mean]] }
negative = rows.select { _1[:mean] < 0 && _1[:neg_apps] > 0 }.sort_by { _1[:mean] }

label = control ? "A/A interpreter (#{control})" : mode
if tsv
  puts %w[rank site apps workloads mean_extra_objects_per_op classes app_names].join("\t")
  positive.each_with_index { |r, i| puts [i + 1, r[:site], r[:apps], r[:workloads], r[:mean].round(3), r[:classes].join(","), r[:app_names].join(",")].join("\t") }
else
  moved = totals.map(&:last)
  puts "#{label} - interpreter: #{base.size} runs, #{total} workloads; median workload delta #{format("%+.1f", median(moved))}, " \
    ">= +1: #{moved.count { _1 >= 1 }}, <= -1: #{moved.count { _1 <= -1 }}, mean #{format("%+.1f", moved.sum / total)}"
  puts "JIT allocates more:"
  positive.first(limit).each_with_index do |r, i|
    puts format("%3d %-70s apps %d wl %3d mean %+7.2f %s", i + 1, r[:site][-70..] || r[:site], r[:apps], r[:workloads], r[:mean], r[:classes].join(","))
  end
  puts "JIT allocates less (attribution shifts or real savings):"
  negative.first(limit / 2).each do |r|
    puts format("    %-70s apps %d wl %3d mean %+7.2f", r[:site][-70..] || r[:site], r[:neg_apps], r[:neg_workloads], r[:mean])
  end
end
