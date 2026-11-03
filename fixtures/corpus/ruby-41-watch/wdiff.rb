# wdiff.rb OLD.json NEW.json WORKLOAD [N]
require "json"
o, n, w, lim = ARGV
lim = (lim || 25).to_i
norm = ->(f) { f.sub(%r{\AGEM/[^/]+/(bundler/)?gems/}, "GEM/") }
get = ->(path) { JSON.parse(File.read(path))["workloads"].find { _1["workload"] == w } }
a = get.(o); b = get.(n)
agg = ->(x) { h = Hash.new(0.0); x["sites"].each { |s| h["#{norm.(s["file"])}:#{s["line"]} #{s["class"]}"] += s["objects_per_op"] }; h }
ha = agg.(a); hb = agg.(b)
d = (ha.keys | hb.keys).map { [_1, hb[_1] - ha[_1], ha[_1]] }.reject { _2.abs < 0.5 }
puts "#{w}: old #{a["gc_enabled_objects_per_op"]} new #{b["gc_enabled_objects_per_op"]}"
d.sort_by { -_2 }.first(lim).each { puts format("  %+7.1f (old %6.1f) %s", _2, _3, _1) }
puts "  ..."
d.sort_by { _2 }.first(lim).each { puts format("  %+7.1f (old %6.1f) %s", _2, _3, _1) }
