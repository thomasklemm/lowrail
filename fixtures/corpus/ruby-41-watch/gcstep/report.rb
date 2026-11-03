# gs_report.rb KIND MODE [ROUNDS] : one row per pool variant and round.
# Paths are the orb layout of the 2026-11-03 run (docs/upstream/ruby-4.1-regression-watch.md, sweep steps).
#   KIND census: JSON in .lowrail/private/ruby-41-watch/gs-V-R, logs in /tmp/w/gsteps/V-R
#   KIND rb:     JSON and logs in /tmp/w/rbsteps/V-R
# GC sums over the windows; sweep steps pooled over all workloads.
require "json"
kind, mode, rounds = ARGV[0], ARGV[1], (ARGV[2] || "a,b").split(",")
VARIANTS = (ENV["VARIANTS"] || "bytes slots 2xbytes minpages2 slotscap8").split
def pct(a, q) = a.empty? ? 0 : a[[(a.size * q).ceil - 1, 0].max]

def steps(files)
  lazy = []; pause = []; big = []
  files.each do |f|
    d = File.binread(f)
    (d.bytesize / 24).times do |i|
      ns, pages, slots, _freed, ss, ctx, _h = d.byteslice(i * 24, 24).unpack("Q<L<L<L<S<CC")
      case ctx
      when 1 then lazy << [ns, pages, slots]; big << [ns, pages, slots] if ss >= 512
      when 8 then pause << [ns, pages, slots]
      end
    end
  end
  [lazy, pause, big]
end

APPS = ENV["APPS"]&.split(",")
def keep?(f) = APPS.nil? || APPS.any? { |a| File.basename(f).start_with?("#{a}-interpreter", "#{a}-yjit", "#{a}-zjit") }
def dist(r, i) = (a = r.map { _1[i] }.sort; [pct(a, 0.99), a.last.to_i])

printf("%-10s %-2s %6s %6s %8s %9s | %-24s | %-22s | %-20s | %-18s | %s\n", "variant", "r", "majors", "minors", "GC ms", "RSS MB",
  "pause us p99/max", "pause pages p99/max", "lazy pg p99/max", "big-heap pg p99/max", "big-heap us p99/max")
VARIANTS.each do |v|
  rounds.each do |r|
    if kind == "census"
      js = Dir["/home/user/workspace/repo/.lowrail/private/ruby-41-watch/gs-#{v}-#{r}/*-#{mode}.json"].select { keep?(_1) }.map { JSON.parse(File.read(_1)) }
      g = js.flat_map { |j| j["workloads"].map { _1["gc_long"] } }.compact
      bins = Dir["/tmp/w/gsteps/#{v}-#{r}/*-#{mode}-*.bin"].select { keep?(_1) }
      rss = g.sum { _1["rss_kb_growth"] } / 1024.0
    else
      g = Dir["/tmp/w/rbsteps/#{v}-#{r}/*-#{mode}.json"].select { keep?(_1) }.map { JSON.parse(File.read(_1)) }
      bins = Dir["/tmp/w/rbsteps/#{v}-#{r}/*-#{mode}.bin"].select { keep?(_1) }
      rss = g.sum { _1["rss_kb_peak"] } / 1024.0
    end
    next if g.empty?
    lazy, pause, big = steps(bins)
    pu = dist(pause, 0).map { _1 / 1000 }
    printf("%-10s %-2s %6d %6d %8d %9.1f | %10d / %-11d | %9d / %-10d | %8d / %-9d | %7d / %-8d | %6d / %d\n", v, r,
      g.sum { _1["major_gc_count"] }, g.sum { _1["minor_gc_count"] }, g.sum { _1["time"] }, rss,
      *pu, *dist(pause, 1), *dist(lazy, 1), *dist(big, 1), *dist(big, 0).map { _1 / 1000 })
  end
end
