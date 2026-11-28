# ruby report.rb [OUT] -- queue.sh's results: shipit (OUT/gcstep/V-R/shipit-MODE.json), the ruby-bench suite
# (OUT/split/V-R/BENCH-MODE.json) and the census (.lowrail/private/census/spV-R/APP-MODE.json). OUT defaults to ~/w/out.
# Medians with min-max over rounds; paired rows are per round, with the number of rounds where the first build is lower.
require "json"
OUT = ARGV[0] || File.expand_path("~/w/out")
CENSUS = ENV.fetch("CENSUS_DIR", "/home/user/workspace/repo/.lowrail/private/census")
NAMES = { "base" => "base", "base2" => "base2 (A/A)", "c1" => "c1 (commit 1)", "head" => "head",
          "nocad" => "nocad (head, 2x limit)" }
PAIRS = [%w[base2 base], %w[head base], %w[nocad base], %w[head nocad], %w[c1 head], %w[head base2], %w[nocad base2]]
MODES = %w[interp yjit zjit]
def med(a) = (s = a.sort; s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0)
def cell(a, f = "%.0f") = a.empty? ? "–" : "#{format(f, med(a))} (#{format(f, a.min)}–#{format(f, a.max)})"
def json(f) = File.exist?(f) ? JSON.parse(File.read(f)) : nil
def rounds(dir) = Dir["#{OUT}/#{dir}/*-*"].map { File.basename(_1)[/-(\d+)$/, 1].to_i }.uniq.sort
def by_reason(gcs) = gcs.each_with_object(Hash.new(0)) { |g, h| h[g[0]] += 1 if g[0] }
def fmt_by(h) = h.empty? ? "–" : h.sort.map { "#{_1} #{_2}" }.join(", ")
def paired(rows_a, rows_b, metrics)
  rs = rows_a.keys & rows_b.keys
  return nil if rs.empty?
  metrics.map do |name, f, fmt|
    d = rs.map { f.(rows_a[_1]) - f.(rows_b[_1]) }
    "#{name} #{cell(d, fmt)} lower #{d.count(&:negative?)}/#{rs.size}"
  end.join("; ")
end

# ---- shipit
rs = rounds("gcstep")
puts "## shipit (rounds #{rs.join(",")}; 15 warmups + 40 measured iterations; median (min-max) over rounds)"
puts "| mode | build | n | majors | minors | GC ms | sampled peak RSS MiB | end RSS MiB | wall s | completed majors by reason | limit after majors |"
puts "|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|"
ship = {}
MODES.each do |mode|
  NAMES.each_key do |v|
    js = rs.to_h { [_1, json("#{OUT}/gcstep/#{v}-#{_1}/shipit-#{mode}.json")] }.compact
    next if js.empty?
    ship[[mode, v]] = js
    ok = js.values
    by = Hash.new(0); fac = Hash.new(0)
    ok.each { |j| j["gcs"].each { |b, _ms, _o0, after, lim| next unless b; by[b] += 1; fac[(lim.to_f / after).round(2)] += 1 } }
    printf("| %s | %s | %d | %s | %s | %s | %s | %s | %s | %s | %s |\n", mode, NAMES[v], ok.size,
      cell(ok.map { _1["major_gc_count"] }), cell(ok.map { _1["minor_gc_count"] }), cell(ok.map { _1["time"] }),
      cell(ok.map { _1["rss_kb_peak"] / 1024.0 }), cell(ok.map { _1["rss_kb_end"] / 1024.0 }),
      cell(ok.map { _1["wall_s"] }, "%.1f"), fmt_by(by), fac.sort.map { "#{_1}x #{_2}" }.join(", "))
  end
end
puts "\nshipit majors per round:"
MODES.each { |m| NAMES.each_key { |v| (j = ship[[m, v]]) && puts("  #{m} #{v}: #{j.sort.map { _2["major_gc_count"] }.join(", ")}") } }
puts "\nshipit paired by round: difference median (min-max), rounds where the first build is lower"
SHIP_M = [["majors", -> { _1["major_gc_count"] }, "%+.0f"], ["minors", -> { _1["minor_gc_count"] }, "%+.0f"],
          ["GC ms", -> { _1["time"] }, "%+.0f"], ["peak RSS MiB", -> { _1["rss_kb_peak"] / 1024.0 }, "%+.1f"],
          ["end RSS MiB", -> { _1["rss_kb_end"] / 1024.0 }, "%+.1f"], ["wall s", -> { _1["wall_s"] }, "%+.2f"]]
MODES.each do |mode|
  PAIRS.each do |a, b|
    s = paired(ship[[mode, a]] || {}, ship[[mode, b]] || {}, SHIP_M) or next
    puts "  #{mode} #{a} - #{b}: #{s}"
  end
end

# ---- ruby-bench suite
rs = rounds("split")
benches = Dir["#{OUT}/split/*/*.json"].map { File.basename(_1, ".json").sub(/-(interp|yjit|zjit)$/, "") }.uniq.sort
suite = {}
summ = lambda do |j|
  t = j["times_s"]; n = j["gcs_warmup"] || 0; g = j["gcs"] || []
  { ms: med(t) * 1000, majors: j["bench"]["major_gc_count"], minors: j["bench"]["minor_gc_count"],
    gc_ms: j["bench"]["time"], run_majors: j["run"]["major_gc_count"], proc_majors: j["process"]["major_gc_count"],
    by_bench: by_reason(g[n..] || []), by_run: by_reason(g), hwm: j["vmhwm_kb"] / 1024.0,
    steady: med(j["rss_kb"]) / 1024.0, after_gc: j["rss_kb_after_full_gc"] / 1024.0 }
end
benches.each do |b|
  MODES.each do |mode|
    NAMES.each_key do |v|
      js = rs.to_h { [_1, json("#{OUT}/split/#{v}-#{_1}/#{b}-#{mode}.json")] }.compact
      suite[[b, mode, v]] = js.transform_values(&summ) unless js.empty?
    end
  end
end
puts "\n## ruby-bench suite (rounds #{rs.join(",")}; median (min-max) over rounds of: median iteration ms; GC counts and time over the measured iterations; majors over the whole run from the first warmup; VmHWM = true peak RSS of the process; steady RSS = median of RSS after each measured iteration; after-GC RSS = Rss after a final full GC, ruby-bench's RSS column)"
puts "| bench | mode | build | n | itr ms | majors | minors | GC ms | majors whole run | majors by reason, whole run | VmHWM MiB | steady RSS MiB | after-GC RSS MiB |"
puts "|---|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|"
benches.each do |b|
  MODES.each do |mode|
    NAMES.each_key do |v|
      r = suite[[b, mode, v]] or next
      x = r.values
      by = x.map { _1[:by_run] }.inject { |h, k| h.merge(k) { _2 + _3 } }
      printf("| %s | %s | %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", b, mode, NAMES[v], x.size,
        cell(x.map { _1[:ms] }, "%.1f"), cell(x.map { _1[:majors] }), cell(x.map { _1[:minors] }), cell(x.map { _1[:gc_ms] }),
        cell(x.map { _1[:run_majors] }), fmt_by(by), cell(x.map { _1[:hwm] }, "%.1f"), cell(x.map { _1[:steady] }, "%.1f"),
        cell(x.map { _1[:after_gc] }, "%.1f"))
    end
  end
end
puts "\nsuite paired by round, ratio first/second build in % (median (min-max)), rounds where the first build is lower; majors as differences"
pct = ->(k) { ->(a, b) { (a[k].to_f / b[k] - 1) * 100 } }
SUITE_M = [["itr", pct.(:ms)], ["GC ms", pct.(:gc_ms)], ["VmHWM", pct.(:hwm)], ["steady RSS", pct.(:steady)],
           ["after-GC RSS", pct.(:after_gc)]]
benches.each do |b|
  MODES.each do |mode|
    PAIRS.each do |a, c|
      x = suite[[b, mode, a]]; y = suite[[b, mode, c]]
      next unless x && y
      rr = x.keys & y.keys
      next if rr.empty?
      parts = SUITE_M.map do |n, f|
        d = rr.map { f.(x[_1], y[_1]) }
        "#{n} #{cell(d, "%+.1f")}% #{d.count(&:negative?)}/#{rr.size}"
      end
      dm = rr.map { x[_1][:run_majors] - y[_1][:run_majors] }
      puts "  #{b} #{mode} #{a} - #{c}: majors whole run #{cell(dm, "%+.0f")}; #{parts.join("; ")}"
    end
  end
end

# ---- census
APPS = %w[blog fizzy lobsters]
rs = Dir["#{CENSUS}/sp*-*"].map { _1[/-(\d+)$/, 1].to_i }.uniq.sort
puts "\n## Rails workloads (35 workloads; rounds #{rs.join(",")}; median (min-max); RSS at end and peak summed over the three apps)"
puts "| mode | app | build | n | majors (nofree) | minors | GC ms | RSS at end MiB | peak RSS MiB |"
puts "|---|---|---|---:|---:|---:|---:|---:|---:|"
cen = {}
%w[interpreter yjit zjit].each do |mode|
  (APPS + ["all"]).each do |app|
    NAMES.each_key do |v|
      rows = rs.filter_map do |r|
        js = (app == "all" ? APPS : [app]).map { json("#{CENSUS}/sp#{v}-#{r}/#{_1}-#{mode}.json") }
        next if js.any?(&:nil?)
        gl = js.flat_map { |j| j["workloads"].map { _1["gc_long"] } }
        [r, { majors: gl.sum { _1["major_gc_count"] }, nofree: gl.sum { _1.dig("major_by", "nofree").to_i },
              by: gl.each_with_object(Hash.new(0)) { |g, h| (g["major_by"] || {}).each { |k, n| h[k] += n } },
              minors: gl.sum { _1["minor_gc_count"] }, time: gl.sum { _1["time"] }, nw: gl.size,
              rss_end: js.sum { _1["workloads"].last.dig("gc_long", "rss_kb_end").to_f } / 1024,
              hwm: js.sum { _1["workloads"].map { |w| w.dig("gc_long", "rss_kb_hwm").to_f }.max } / 1024 }]
      end.to_h
      next if rows.empty?
      cen[[mode, app, v]] = rows
      x = rows.values
      printf("| %s | %s | %s | %d | %s (%s) | %s | %s | %s | %s |\n", mode == "interpreter" ? "interp" : mode, app, NAMES[v],
        x.size, cell(x.map { _1[:majors] }), cell(x.map { _1[:nofree] }), cell(x.map { _1[:minors] }),
        cell(x.map { _1[:time] }), cell(x.map { _1[:rss_end] }), cell(x.map { _1[:hwm] }))
      puts "  (workloads per round: #{x.map { _1[:nw] }.uniq.join(",")}; major_by: #{rows.sort.map { _2[:by].sort.to_h }.inspect})" if app == "all"
    end
  end
end
puts "\nCensus paired by round: difference median (min-max), rounds where the first build is lower"
CEN_M = [["majors", -> { _1[:majors] }, "%+.0f"], ["GC ms", -> { _1[:time] }, "%+.0f"],
         ["RSS end MiB", -> { _1[:rss_end] }, "%+.1f"], ["peak MiB", -> { _1[:hwm] }, "%+.1f"]]
%w[interpreter yjit zjit].each do |mode|
  (APPS + ["all"]).each do |app|
    PAIRS.each do |a, b|
      s = paired(cen[[mode, app, a]] || {}, cen[[mode, app, b]] || {}, CEN_M) or next
      puts "  #{mode} #{app} #{a} - #{b}: #{s}"
    end
  end
end
