# frozen_string_literal: true

# Census 12 net report: LABEL against BASE, per workload and per method.
#   ruby net.rb DIR MODE BASE LABEL [AA_LABEL] [--limit N]
# Workloads: relative change in client Ir per operation, per app, over workloads
# measured (and, under YJIT, JIT-flat) in every given label. AA_LABEL, a second
# run of LABEL, gives each workload's A/A and second-run change; `*` marks a
# workload that moves beyond 1% the same way in both runs.
# Methods: self Ir per operation summed over those workloads, keyed by file and
# method label (lines move between trees), as % of all BASE instructions; the
# A/A column is the same net between LABEL and AA_LABEL.
require "json"

dir, mode, base, label, aa = ARGV.reject { _1.start_with?("--") || _1 =~ /\A\d+\z/ }
limit = (ARGV.index("--limit") && Integer(ARGV[ARGV.index("--limit") + 1])) || 40
labels = [base, label, aa].compact

def load(dir, label, mode)
  Dir["#{dir}/#{label}/*-#{mode}.json"].to_h do |path|
    run = JSON.parse(File.read(path))
    [run["app"], run["workloads"].to_h { [_1["workload"], _1] }]
  end
end

def norm(file) = file.sub(%r{/gems/([a-z0-9_.-]+?)-\d[\w.]*(-x86_64-linux(-gnu)?)?/}, '/gems/\1/')

# Anonymous classes and compiled template methods carry addresses and hashes that differ per process.
def label(method) = method.gsub(/0x\h+/, "0x").sub(/_{2,3}-?\d+_\d+\z/, "")

runs = labels.to_h { [_1, load(dir, _1, mode)] }
apps = runs[base].keys.sort
rows = []
apps.each do |app|
  runs[base][app].each_key do |w|
    ws = labels.map { runs.dig(_1, app, w) }
    next if ws.any?(&:nil?)
    next unless ws.all? { _1.fetch("jit_flat", true) }
    rows << [app, w, *ws]
  end
end
rejected = apps.sum { |app| runs[base][app].count { |w, _| labels.any? { (x = runs.dig(_1, app, w)) && !x.fetch("jit_flat", true) } } }

pct = ->(a, b) { 100 * (a / b - 1) }
med = ->(a) { s = a.sort; s.empty? ? 0 : (s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2) }
puts "# #{base} -> #{label}#{" (A/A #{aa})" if aa}, #{mode}: #{rows.size} workloads, #{rejected} left out as not JIT-flat in some label"
apps.each do |app|
  r = rows.select { _1[0] == app }
  next if r.empty?
  d = r.map { pct.(_1[3]["ir_per_op"], _1[2]["ir_per_op"]) }
  a = aa ? r.map { pct.(_1[4]["ir_per_op"], _1[3]["ir_per_op"]).abs } : []
  o = r.map { _1[3]["objects_per_op"] - _1[2]["objects_per_op"] }
  printf("%-18s %3d wl  median %+7.2f%%  min %+7.2f%%  max %+7.2f%%%s  objects median %+8.1f\n", app, r.size, med.(d), d.min, d.max,
    aa ? format("  A/A median %.2f%%", med.(a)) : "", med.(o))
end
all = rows.map { pct.(_1[3]["ir_per_op"], _1[2]["ir_per_op"]) }
printf("ALL %d workloads: median %+.2f%%, faster %d, slower %d (beyond 1%%)\n\n", rows.size, med.(all), all.count { _1 <= -1 }, all.count { _1 >= 1 })

puts "# workloads, change and A/A"
rows.sort_by { -pct.(_1[3]["ir_per_op"], _1[2]["ir_per_op"]) }.each do |app, w, b, l, a2|
  d = pct.(l["ir_per_op"], b["ir_per_op"])
  aav = a2 ? pct.(a2["ir_per_op"], l["ir_per_op"]) : nil
  second = a2 ? pct.(a2["ir_per_op"], b["ir_per_op"]) : nil
  printf("%+7.2f%%%s %s  Ir/op %12.0f -> %12.0f  obj %+7.1f  %s %s\n", d, a2 ? format(" (2nd %+7.2f%%, A/A %+6.2f%%)", second, aav) : "",
    (a2 && d.abs > 1 && second.abs > 1 && (d <=> 0) == (second <=> 0)) ? "*" : " ", b["ir_per_op"], l["ir_per_op"],
    l["objects_per_op"] - b["objects_per_op"], app, w)
end

total = rows.sum { _1[2]["ir_per_op"] }
methods = ->(w) { h = Hash.new(0.0); w["methods"].each { h["#{norm(_1["file"])} #{label(_1["method"])}"] += _1["self_ir_per_op"] }; h }
net = Hash.new(0.0)
aanet = Hash.new(0.0)
reach = Hash.new { |h, k| h[k] = {} }
rows.each do |app, _w, b, l, a2|
  mb, ml = methods.(b), methods.(l)
  (mb.keys | ml.keys).each do |k|
    d = ml[k] - mb[k]
    net[k] += d
    reach[k][app] = true if d.abs >= 1000
  end
  next unless a2
  ma = methods.(a2)
  (ml.keys | ma.keys).each { |k| aanet[k] += ma[k] - ml[k] }
end
show = ->(title, list) do
  puts "\n# #{title}: net self Ir by method, % of all #{base} instructions#{" (A/A: #{label} -> #{aa})" if aa}"
  list.first(limit).each do |k, v|
    printf("%+8.3f%%%s %d apps  %s\n", 100 * v / total, aa ? format(" (A/A %+7.3f%%)", 100 * aanet[k] / total) : "", reach[k].size, k)
  end
end
show.("grew", net.select { _2 > 0 }.sort_by { -_2 })
show.("shrank", net.select { _2 < 0 }.sort_by { _2 })
