# perapp.rb OLDA OLDB NEWA NEWB MODE [NEWMODE]
require "json"
oa, ob, na, nb, mode, nmode = ARGV; nmode ||= mode
med = ->(a) { a.sort[a.size / 2] }
load = ->(l, m) { Dir["#{l}/*-#{m}.json"].to_h { |f| j = JSON.parse(File.read(f)); [j["app"], j["workloads"].to_h { [_1["workload"], [med.(_1["gc_enabled_objects_per_op"]), _1["enumerated_bytes"].to_f / _1["ops"]]] }] } }
o1, o2, n1, n2 = load.(oa, mode), load.(ob, mode), load.(na, nmode), load.(nb, nmode)
all = [[], [], []]
o1.keys.sort.each do |app|
  d = o1[app].keys.map { |w| o = (o1[app][w][0] + o2[app][w][0]) / 2; n = (n1[app][w][0] + n2[app][w][0]) / 2; ob_ = (o1[app][w][1] + o2[app][w][1]) / 2; nb_ = (n1[app][w][1] + n2[app][w][1]) / 2; [n - o, 100 * (n - o) / o, 100 * (nb_ - ob_) / ob_] }
  3.times { |i| all[i].concat(d.map { _1[i] }) }
  printf("| %s | %d | %+.1f | %+.2f%% | %+.1f%% |\n", app, d.size, med.(d.map { _1[0] }), med.(d.map { _1[1] }), med.(d.map { _1[2] }))
end
printf("| **All** | %d | **%+.1f** | **%+.2f%%** | **%+.1f%%** |\n", all[0].size, med.(all[0]), med.(all[1]), med.(all[2]))
