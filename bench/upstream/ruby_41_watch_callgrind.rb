# frozen_string_literal: true

# Instructions per operation from census 4 Callgrind windows, two Rubies with
# an A/A pair each. ruby SCRIPT ROOT DUMPS OLD_A OLD_B NEW_A NEW_B
# Each workload has three dumps (seam, total, no_gc); per operation is
# (window - seam) / ops. no_gc excludes collector segments.
require "json"

root, dumps, *labels = ARGV
total = lambda do |path|
  line = File.foreach(path).find { _1.start_with?("totals: ") || _1.start_with?("summary: ") }
  raise "no totals: #{path}" unless line
  Integer(line.split.fetch(1))
end
load_label = lambda do |label|
  Dir[File.join(root, label, "*-interpreter.json")].sort.flat_map do |file|
    run = JSON.parse(File.read(file))
    app = run["app"]
    run["workloads"].map do |w|
      cg = w.fetch("callgrind")
      seam, tot, nogc = cg.map { total.(File.join(dumps, label, "#{app}.cg.#{_1["dump"]}")) }
      ops = cg[1]["ops"]
      [[app, w["workload"]], { total: (tot - seam).fdiv(ops), no_gc: (nogc - seam).fdiv(ops), gc: cg[1]["gc_count"] }]
    end
  end.to_h
end
oa, ob, na, nb = labels.map(&load_label)
keys = [oa, ob, na, nb].map(&:keys).reduce(:&)
median = ->(a) { a.sort[a.size / 2] }
%i[no_gc total].each do |metric|
  rows = keys.map do |k|
    old = (oa[k][metric] + ob[k][metric]) / 2
    new = (na[k][metric] + nb[k][metric]) / 2
    aa = [(oa[k][metric] - ob[k][metric]).abs / old, (na[k][metric] - nb[k][metric]).abs / new].max
    [k, old, 100 * (new - old) / old, 100 * aa, oa[k][:gc] + ob[k][:gc], na[k][:gc] + nb[k][:gc]]
  end
  puts "== #{metric}: instructions per operation, #{labels[0..1].join("/")} -> #{labels[2..3].join("/")}"
  rows.sort_by { -_1[2] }.each do |k, old, d, aa, g0, g1|
    flag = d.abs > 2 * aa && d.abs >= 1.0 ? (d.positive? ? "SLOWER" : "FASTER") : ""
    puts format("%-7s %-56s %12.0f %+7.2f%% (aa %.2f%%) gc %d->%d", flag, k.join(" ")[0, 56], old, d, aa, g0, g1)
  end
  ds = rows.map { _1[2] }
  aas = rows.map { _1[3] }
  puts format("ALL %s: %d workloads, median %+.2f%%, geomean %+.2f%%, A/A median %.2f%% max %.2f%%, slower %d, faster %d",
    metric, rows.size, median.(ds), 100 * (Math.exp(ds.sum { Math.log(1 + _1 / 100) } / ds.size) - 1),
    median.(aas), aas.max, rows.count { _1[2] > 2 * _1[3] && _1[2] >= 1 }, rows.count { -_1[2] > 2 * _1[3] && _1[2] <= -1 })
end
