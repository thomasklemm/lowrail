# Hash objects per operation per workload: 4.0.7 -> master -> fix (MODE, labels A).
require "json"
mode = ARGV[0]
h = ->(l) { Dir["#{l}/*-#{mode}.json"].sort.flat_map { |f| o = JSON.parse(File.read(f)); o["workloads"].map { |w| [[o["app"], w["workload"]], w["sites"].sum { _1["class"] == "Hash" ? _1["objects_per_op"] : 0 }] } }.to_h }
o, m, x = %w[r407a rmasa rfita].map(&h)
k = o.keys & m.keys & x.keys
med = ->(a) { a.sort[a.size / 2] }
dm = k.map { m[_1] - o[_1] }; dx = k.map { x[_1] - o[_1] }
puts format("%s %d workloads: Hash/op median 4.0.7 %.1f; master-4.0.7 median %+.1f mean %+.1f; fix-4.0.7 median %+.1f mean %+.1f; workloads with master > 4.0.7+1: %d, fix > 4.0.7+1: %d",
  mode, k.size, med.(k.map { o[_1] }), med.(dm), dm.sum / k.size, med.(dx), dx.sum / k.size, dm.count { _1 > 1 }, dx.count { _1 > 1 })
