# ruby report.rb -- queue.sh's results, as vs17251-2026-11-24/report5.rb: shipit rounds 1-6
# (~/w/gcrb/V-R/shipit-MODE.json) and census rounds 1-5 (.lowrail/private/census/gcV-R/APP-MODE.json), builds base,
# base2 (A/A copy of base) and head. Medians with min-max; paired rows count rounds where the first build is lower.
require "json"
W = File.expand_path("~/w")
CENSUS = "/home/user/workspace/repo/.lowrail/private/census"
NAMES = { "base" => "base f6278067b6", "base2" => "base (A/A copy)", "head" => "head 9715d0224e" }
PAIRS = [%w[head base], %w[base2 base], %w[head base2]]
def med(a) = (s = a.sort; s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0)
def cell(a, f = "%.0f") = a.empty? ? "–" : "#{format(f, med(a))} (#{format(f, a.min)}–#{format(f, a.max)})"
def json(f) = File.exist?(f) ? JSON.parse(File.read(f)) : nil

puts "## shipit, rounds 1-6 (median (min-max) over rounds; 40 measured iterations after 15 warmups)"
puts "| mode | build | n | majors | minors | GC ms | sampled peak RSS MiB | end RSS MiB | wall s |"
puts "|---|---|---:|---:|---:|---:|---:|---:|---:|"
ship = {}
%w[interp yjit zjit].each do |mode|
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
puts "\nshipit paired by round: diff median (min-max), rounds where the first build is lower"
%w[interp yjit zjit].each do |mode|
  PAIRS.each do |a, b|
    pr = ship[[mode, a]].zip(ship[[mode, b]]).select { _1 && _2 }
    next if pr.empty?
    s = { "GC ms" => ["time", 1.0], "peak RSS MiB" => ["rss_kb_peak", 1024.0], "majors" => ["major_gc_count", 1.0] }.map do |n, (k, div)|
      d = pr.map { (_1[k] - _2[k]) / div }
      "#{n} #{cell(d, "%+.1f")} lower #{d.count(&:negative?)}/#{pr.size}"
    end
    puts "  #{mode} #{a} - #{b}: #{s.join("; ")}"
  end
end

puts "\n## shipit attribution, rounds h1-h3 (per-GC records; attrib.sh)"
puts "| mode | build | completed majors by reason | limit factor after majors | ms per major | major ms per round | minor ms per round | GC ms per round (stat) | majors per round (stat) |"
puts "|---|---|---|---|---:|---:|---:|---:|---:|"
%w[interp yjit zjit].each do |mode|
  %w[base head].each do |v|
    js = (1..3).filter_map { json("#{W}/gcrb/#{v}-h#{_1}/shipit-#{mode}.json") }
    next if js.empty?
    by = Hash.new(0); factors = []; maj_ms = []; min_ms = []
    js.each do |j|
      j["gcs"].each do |by_, ms, _before, after, limit|
        if by_
          by[by_] += 1; factors << (limit.to_f / after).round(2); maj_ms << ms
        else
          min_ms << ms
        end
      end
    end
    printf("| %s | %s | %s | %s | %.0f | %.0f | %.0f | %.0f | %s |\n", mode, NAMES[v], by.sort.map { "#{_1} #{_2}" }.join(", "),
      factors.tally.sort.map { "#{_1}x #{_2}" }.join(", "), maj_ms.sum.fdiv([maj_ms.size, 1].max), maj_ms.sum / js.size.to_f,
      min_ms.sum / js.size.to_f, js.sum { _1["time"] } / js.size.to_f, js.map { _1["major_gc_count"] }.join(", "))
  end
end

puts "\n## census, rounds 1-5 (median (min-max) over rounds; RSS at end and peak are summed over the three apps)"
APPS = %w[blog fizzy lobsters]
puts "| mode | app | build | n | majors (nofree) | minors | GC ms | RSS at end of app MiB | peak RSS MiB |"
puts "|---|---|---|---:|---:|---:|---:|---:|---:|"
cen = {}
%w[interpreter yjit zjit].each do |mode|
  (APPS + ["all"]).each do |app|
    NAMES.each_key do |v|
      rows = (1..5).filter_map do |r|
        js = (app == "all" ? APPS : [app]).map { json("#{CENSUS}/gc#{v}-#{r}/#{_1}-#{mode}.json") }
        next if js.any?(&:nil?)
        gl = js.flat_map { |j| j["workloads"].map { _1["gc_long"] } }
        { majors: gl.sum { _1["major_gc_count"] }, nofree: gl.sum { _1.dig("major_by", "nofree").to_i },
          by: gl.each_with_object(Hash.new(0)) { |g, h| (g["major_by"] || {}).each { |k, n| h[k] += n } },
          minors: gl.sum { _1["minor_gc_count"] }, time: gl.sum { _1["time"] }, nw: gl.size,
          rss_end: js.sum { _1["workloads"].last.dig("gc_long", "rss_kb_end").to_f } / 1024,
          hwm: js.sum { _1["workloads"].map { |w| w.dig("gc_long", "rss_kb_hwm").to_f }.max } / 1024, round: r }
      end
      next if rows.empty?
      cen[[mode, app, v]] = rows
      printf("| %s | %s | %s | %d | %s (%s) | %s | %s | %s | %s |\n", mode == "interpreter" ? "interp" : mode, app, NAMES[v], rows.size,
        cell(rows.map { _1[:majors] }), cell(rows.map { _1[:nofree] }), cell(rows.map { _1[:minors] }), cell(rows.map { _1[:time] }),
        cell(rows.map { _1[:rss_end] }), cell(rows.map { _1[:hwm] }))
      puts "  (workloads per round: #{rows.map { _1[:nw] }.uniq.join(",")}; major_by: #{rows.map { _1[:by].sort.to_h }.inspect})" if app == "all"
    end
  end
end
puts "\nCensus paired by round: diff median (min-max), rounds where the first build is lower"
%w[interpreter yjit zjit].each do |mode|
  (APPS + ["all"]).each do |app|
    PAIRS.each do |a, b|
      x = (cen[[mode, app, a]] || []).to_h { [_1[:round], _1] }; y = (cen[[mode, app, b]] || []).to_h { [_1[:round], _1] }
      rs = x.keys & y.keys
      next if rs.empty?
      s = %i[majors time rss_end hwm].map do |k|
        d = rs.map { x[_1][k] - y[_1][k] }
        "#{k} #{cell(d, "%+.1f")} lower #{d.count(&:negative?)}/#{rs.size}"
      end
      puts "  #{mode} #{app} #{a} - #{b}: #{s.join("; ")}"
    end
  end
end
