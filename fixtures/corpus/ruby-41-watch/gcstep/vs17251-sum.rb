# sum.rb MODE : 4 builds x rounds a,b over the workloads every cell ran
require "json"
mode = ARGV[0]
base = "/home/user/workspace/repo/.lowrail/private/ruby-41-watch"
cells = %w[master pr pool both].product(%w[a b])
data = cells.to_h do |v, r|
  h = {}
  Dir["#{base}/gs-#{v}-#{r}/*-#{mode}.json"].each do |f|
    app = File.basename(f, "-#{mode}.json")
    JSON.parse(File.read(f))["workloads"].each { |w| h[[app, w["workload"]]] = w["gc_long"] if w["gc_long"] }
  end
  [[v, r], h]
end
common = data.values.map(&:keys).reduce(:&)
dropped = data.values.flat_map(&:keys).uniq - common
def pct(a, q) = a.empty? ? 0 : a[[(a.size * q).ceil - 1, 0].max]
puts "#{mode}: #{common.size} workloads in #{common.map(&:first).uniq.size} apps; dropped #{dropped.inspect}"
per_app = Hash.new { |h, k| h[k] = {} }
cells.each do |v, r|
  g = common.map { data[[v, r]][_1] }
  by = Hash.new(0); heap = Hash.new(0)
  g.each { |w| w["major_by"].each { |k, n| by[k] += n }; w["forced_major_by_slot"].each { |s, n| heap[s] += n } }
  pause = []
  common.each do |app, wl|
    f = "/tmp/w/gsteps/#{v}-#{r}/#{app}-#{mode}-#{wl.gsub(/[^\w.-]/, "_")}.bin"
    next unless File.exist?(f)
    d = File.binread(f)
    (d.bytesize / 24).times { |i| ns, *, ctx, _ = d.byteslice(i * 24, 24).unpack("Q<L<L<L<S<CC"); pause << ns if ctx == 8 }
  end
  pause.sort!
  common.group_by(&:first).each { |app, ks| per_app[app][[v, r]] = ks.sum { data[[v, r]][_1]["major_gc_count"] } }
  printf("%-6s %s majors %4d  all %5d  GC %6.1f s  RSS %+7.1f MB  pause p99 %.2f max %.1f ms (n=%d)  by %p  forced %p\n", v, r,
    g.sum { _1["major_gc_count"] }, g.sum { _1["count"] }, g.sum { _1["time"] } / 1000.0, g.sum { _1["rss_kb_growth"] } / 1024.0,
    pct(pause, 0.99) / 1e6, pause.last.to_i / 1e6, pause.size, by, heap.reject { _2.zero? }.sort_by { -_2 }.to_h)
end
puts "majors per app (a/b): master | pr | pool | both"
per_app.each { |app, h| puts format("%-18s %s", app, %w[master pr pool both].map { |v| "#{h[[v, "a"]]}/#{h[[v, "b"]]}" }.join(" | ")) }
