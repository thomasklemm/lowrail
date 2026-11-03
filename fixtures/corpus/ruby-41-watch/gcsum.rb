# GC window sums and per-workload direction counts: gc407a/b vs gcmasa/b for MODE.
require "json"
m = ARGV[0]
ld = ->(l) { Dir["#{l}/*-#{m}.json"].flat_map { |f| j = JSON.parse(File.read(f)); j["workloads"].map { [[j["app"], _1["workload"]], _1["gc_long"]] } }.to_h }
a, b, c, d = (ARGV[1] ? ARGV[1].split(",") : %w[gc407a gc407b gcmasa gcmasb]).map(&ld)
k = a.keys & c.keys
sum = ->(r, x) { k.sum { |w| r[w][x] } }
%w[major_gc_count minor_gc_count count time rss_kb_growth].each do |x|
  puts format("%s %-15s 4.0.7 %8d %8d   master %8d %8d", m, x, *[a, b, c, d].map { sum.(_1, x) })
end
%w[major_gc_count count].each do |x|
  more = k.count { |w| [c[w][x], d[w][x]].min > [a[w][x], b[w][x]].max }
  less = k.count { |w| [c[w][x], d[w][x]].max < [a[w][x], b[w][x]].min }
  puts "#{m} #{x}: master higher in both runs on #{more} workloads, lower on #{less}"
end
