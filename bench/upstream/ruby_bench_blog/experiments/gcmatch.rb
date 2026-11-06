# gcmatch.rb BENCH BASE VARIANT...: mean Ir over measured iterations (3..7) where every process
# of every listed variant ran the same number of major GCs, so a GC that lands in one arm only drops out.
require "json"
b, *vs = ARGV
runs = vs.to_h { |v| [v, Dir["#{b}~#{v}~*.json"].grep_v(/result/).map { JSON.parse(File.read(_1)) }] }
d = ->(j, i) { j["stats"][i][3] - j["stats"][i - 1][3] }
keep = (3..7).select { |i| runs.values.flatten.map { d[_1, i] }.uniq.size == 1 }
m = runs.transform_values { |js| js.sum { |j| keep.sum { j["irs"][_1] } } / (js.size * keep.size).to_f }
aa = runs.transform_values { |js| ms = js.map { |j| keep.sum { j["irs"][_1] } / keep.size.to_f }; (ms.max - ms.min) / ms.min * 100 }
puts "#{b} iterations kept #{keep.inspect}"
vs.each { |v| printf("  %-8s %.5e  A/A %.4f%%  vs %s %+.3f%%\n", v, m[v], aa[v], vs[0], (m[v] / m[vs[0]] - 1) * 100) }
