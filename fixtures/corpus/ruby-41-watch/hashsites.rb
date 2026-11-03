# Hash objects per op summed over all workloads, per site: OLD vs NEW labels (MODE).
require "json"
old, new, mode, n = ARGV
norm = ->(f) { f.sub(%r{\AGEM/[^/]+/(bundler/)?gems/}, "GEM/") }
agg = ->(l) { t = Hash.new(0.0); Dir["#{l}/*-#{mode}.json"].each { |f| JSON.parse(File.read(f))["workloads"].each { |w| w["sites"].each { |s| t["#{norm.(s["file"])}:#{s["line"]}"] += s["objects_per_op"] if s["class"] == "Hash" } } }; t }
a, b = agg.(old), agg.(new)
d = (a.keys | b.keys).map { [_1, b[_1] - a[_1], a[_1]] }.sort_by { -_2 }
puts format("total Hash/op over workloads: %.0f -> %.0f", a.values.sum, b.values.sum)
d.first(Integer(n || 25)).each { |k, x, o| puts format("%+9.1f (old %8.1f)  %s", x, o, k[0, 130]) }
puts "..."; d.last(8).each { |k, x, o| puts format("%+9.1f (old %8.1f)  %s", x, o, k[0, 130]) }
