# ruby report5.rb -- queue.sh's results: shipit rounds 1-6 (~/w/gcrb/V-R/shipit-MODE.json), attribution rounds h1-h3
# (same, with per-GC records), bigslot (~/w/bigslot/V-I.txt) and census rounds 1-5
# (.lowrail/private/census/gcV-R/APP-MODE.json). Medians with min-max; "new < old in k/n" counts rounds.
require "json"
W = File.expand_path("~/w")
CENSUS = "/home/user/workspace/repo/.lowrail/private/census"
NAMES = { "master" => "master dec1bb786f", "old" => "old head 41c689571a", "new" => "new head 57eb4b4274",
  "m760" => "master 760125a4c5", "mg" => "master dec1bb786f + gcstep patch",
  "og" => "old head + gcstep patch", "ng" => "new head + gcstep patch" }
def med(a) = (s = a.sort; s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0)
def cell(a, f = "%.0f") = a.empty? ? "–" : "#{format(f, med(a))} (#{format(f, a.min)}–#{format(f, a.max)})"
def json(f) = File.exist?(f) ? JSON.parse(File.read(f)) : nil
def wins(a, b) = a.zip(b).count { |x, y| x && y && x < y } # rounds where a < b

puts "## shipit, rounds 1-6 (median (min-max) over rounds)"
puts "| mode | build | n | majors | minors | GC ms | peak RSS MB | end RSS MB | wall s |"
puts "|---|---|---:|---:|---:|---:|---:|---:|---:|"
ship = {}
%w[interp yjit].each do |mode|
  NAMES.each_key do |v|
    js = (1..6).map { json("#{W}/gcrb/#{v}-#{_1}/shipit-#{mode}.json") }
    ship[[mode, v]] = js
    ok = js.compact
    next if ok.empty?
    printf("| %s | %s | %d | %s | %s | %s | %s | %s | %s |\n", mode, NAMES[v], ok.size, cell(ok.map { _1["major_gc_count"] }),
      cell(ok.map { _1["minor_gc_count"] }), cell(ok.map { _1["time"] }), cell(ok.map { _1["rss_kb_peak"] / 1024.0 }),
      cell(ok.map { _1["rss_kb_end"] / 1024.0 }), cell(ok.map { _1["wall_s"] }, "%.1f"))
  end
end
puts "\nPaired by round (same round, same mode): rounds where the first build is lower / rounds"
%w[interp yjit].each do |mode|
  [%w[new old], %w[new master], %w[old master], %w[mg master], %w[new m760]].each do |a, b|
    x, y = ship[[mode, a]], ship[[mode, b]]
    n = x.zip(y).count { _1 && _2 }
    next if n.zero?
    d = ->(k) { x.zip(y).filter_map { |p, q| p[k] - q[k] if p && q } }
    printf("  %s %s - %s: GC ms diff %s, lower %d/%d; peak RSS MB diff %s, lower %d/%d; majors diff %s\n", mode, a, b,
      cell(d.("time")), wins(x.map { _1&.dig("time") }, y.map { _1&.dig("time") }), n,
      cell(d.("rss_kb_peak").map { _1 / 1024.0 }, "%+.1f"),
      wins(x.map { _1&.dig("rss_kb_peak") }, y.map { _1&.dig("rss_kb_peak") }), n, cell(d.("major_gc_count"), "%+.0f"))
  end
end

puts "\n## shipit attribution, rounds h1-h3 (per-GC records)"
puts "| mode | build | majors (nofree / oldgen / other) | nofree with old gen > 1.25x last major | limit factor after majors | ms per major | ms per minor | major ms | minor ms | GC ms (stat) |"
puts "|---|---|---|---:|---|---:|---:|---:|---:|---:|"
%w[interp yjit].each do |mode|
  %w[master old new m760].each do |v|
    js = (1..3).filter_map { json("#{W}/gcrb/#{v}-h#{_1}/shipit-#{mode}.json") }
    next if js.empty?
    by = Hash.new(0); grew = 0; factors = []; maj_ms = []; min_ms = []
    js.each do |j|
      last_after = j["gcs_old0"][0]
      j["gcs"].each do |by_, ms, before, after, limit|
        if by_
          by[by_] += 1
          grew += 1 if by_ == "nofree" && before > last_after * 1.25
          factors << (limit.to_f / after).round(2)
          maj_ms << ms
          last_after = after
        else
          min_ms << ms
        end
      end
    end
    other = by.reject { |k, _| %w[nofree oldgen].include?(k) }
    f = factors.tally.sort.map { "#{_1}x #{_2}" }.join(", ")
    printf("| %s | %s | %d (%d / %d / %s) | %d | %s | %.0f | %.1f | %.0f | %.0f | %.0f |\n", mode, NAMES[v], by.values.sum, by["nofree"], by["oldgen"],
      other.empty? ? "0" : other.map { "#{_1} #{_2}" }.join(" "), grew, f, maj_ms.sum.fdiv([maj_ms.size, 1].max),
      min_ms.sum.fdiv([min_ms.size, 1].max), maj_ms.sum / js.size.to_f, min_ms.sum / js.size.to_f, js.sum { _1["time"] } / js.size.to_f)
  end
end
puts "(major/minor ms are means per round; a GC's ms spans its marking and all its lazy sweep steps)"

puts "\n## bigslot (RING=200 BIG=70 N=40000): nofree majors per run / 640 B heap pages"
puts "(bigslot: queue5.sh; bigslot2: bigslot_gcstep.sh, og/ng = old/new head + gcstep patch, mg = master + gcstep patch)"
[%w[bigslot master old new m760], %w[bigslot2 master mg old og new ng]].each do |dir, *vs|
  puts "#{dir}:"
  vs.each do |v|
    rs = Dir["#{W}/#{dir}/#{v}-*.txt"].sort_by { _1[/-(\d+)\.txt/, 1].to_i }.map { File.read(_1) }
    majors = rs.map { _1[/(\d+) major/, 1] }
    pages = rs.map { _1[/(\d+) pages/, 1] }.tally.map { "#{_1} x#{_2}" }.join(", ")
    puts "  #{NAMES.fetch(v, v)}: #{majors.join(", ")} / pages #{pages}  #{rs.map { _1[/\{.*?\}/] }.uniq.join(" ")}"
  end
end

puts "\n## census, rounds 1-5 (median (min-max) over rounds)"
APPS = %w[blog fizzy lobsters]
puts "| mode | app | build | n | majors (nofree) | minors | GC ms | RSS at end of app MB | peak RSS MB | sum of window growth MB |"
puts "|---|---|---|---:|---:|---:|---:|---:|---:|---:|"
cen = Hash.new { |h, k| h[k] = [] }
%w[interpreter yjit].each do |mode|
  (APPS + ["all"]).each do |app|
    %w[master old new m760].each do |v|
      rows = (1..5).filter_map do |r|
        js = (app == "all" ? APPS : [app]).map { json("#{CENSUS}/gc#{v}-#{r}/#{_1}-#{mode}.json") }
        next if js.any?(&:nil?)
        gl = js.flat_map { |j| j["workloads"].map { _1["gc_long"] } }
        { majors: gl.sum { _1["major_gc_count"] }, nofree: gl.sum { _1.dig("major_by", "nofree").to_i },
          minors: gl.sum { _1["minor_gc_count"] }, time: gl.sum { _1["time"] },
          rss_end: js.sum { _1["workloads"].last.dig("gc_long", "rss_kb_end").to_f } / 1024,
          hwm: js.sum { _1["workloads"].map { |w| w.dig("gc_long", "rss_kb_hwm").to_f }.max } / 1024,
          growth: gl.sum { _1["rss_kb_growth"] } / 1024.0, round: r }
      end
      next if rows.empty?
      cen[[mode, app, v]] = rows
      printf("| %s | %s | %s | %d | %s (%s) | %s | %s | %s | %s | %s |\n", mode == "interpreter" ? "interp" : mode, app, NAMES[v], rows.size,
        cell(rows.map { _1[:majors] }), cell(rows.map { _1[:nofree] }), cell(rows.map { _1[:minors] }), cell(rows.map { _1[:time] }),
        cell(rows.map { _1[:rss_end] }), cell(rows.map { _1[:hwm] }), cell(rows.map { _1[:growth] }, "%+.1f"))
    end
  end
end
puts "\nCensus paired by round: rounds where the first build is lower / rounds"
%w[interpreter yjit].each do |mode|
  (APPS + ["all"]).each do |app|
    [%w[new old], %w[new master], %w[old master], %w[new m760]].each do |a, b|
      x = cen[[mode, app, a]].to_h { [_1[:round], _1] }; y = cen[[mode, app, b]].to_h { [_1[:round], _1] }
      rs = x.keys & y.keys
      next if rs.empty?
      s = %i[time rss_end hwm].map do |k|
        d = rs.map { x[_1][k] - y[_1][k] }
        "#{k} #{cell(d, "%+.1f")} lower #{d.count(&:negative?)}/#{rs.size}"
      end
      puts "  #{mode} #{app} #{a} - #{b}: #{s.join("; ")}"
    end
  end
end
