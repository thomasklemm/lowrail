# [VARIANTS="bytes slots pr17251s"] ruby gc_report.rb DIR MODE [ROUNDS]  -- ruby-bench shipit GC cells (gc_shipit.sh) or census cells (gc_census.sh):
# DIR/VARIANT-ROUND/*-MODE.json (+ .bin step logs from fixtures/corpus/ruby-41-watch/gcstep/gcstep.patch).
# Step record: 24 bytes, "Q<L<L<L<S<CC" = ns, pages, slots, freed, slot_size, ctx, heap; ctx 1 = lazy sweep step,
# 8 = sweep continuation an allocation waits for (as in gcstep/report.rb).
require "json"
dir, mode, rounds = ARGV[0], ARGV[1], (ARGV[2] || "a,b").split(",")
def pct(a, q) = a.empty? ? 0 : a[[(a.size * q).ceil - 1, 0].max]
def steps(files)
  pause = []; big = []
  files.each do |f|
    d = File.binread(f)
    (d.bytesize / 24).times do |i|
      ns, _pages, _slots, _freed, ss, ctx, _h = d.byteslice(i * 24, 24).unpack("Q<L<L<L<S<CC")
      pause << ns if ctx == 8
      big << ns if ctx == 1 && ss >= 512
    end
  end
  [pause.sort, big.sort]
end
puts "| variant | round | majors | minors | GC ms | RSS growth / peak MB | sweep pause p99 / max ms | large-slot step p99 / max ms |"
puts "|---|---|---:|---:|---:|---:|---:|---:|"
(ENV["VARIANTS"] || "bytes slots").split.each do |v|
  rounds.each do |r|
    d = File.join(dir, "#{v}-#{r}")
    jsons = Dir[File.join(d, "*-#{mode}.json")]
    next if jsons.empty?
    js = jsons.map { JSON.parse(File.read(_1)) }
    sum = ->(k) { js.sum { |j| (j[k] || j.dig("gc_long", k) || 0).to_f } }
    rss = js.first.key?("rss_kb_peak") ? format("%.0f", js.sum { _1["rss_kb_peak"] } / 1024.0) : format("%+.0f", js.sum { _1["rss_kb_growth"].to_f } / 1024.0)
    pause, big = steps(Dir[File.join(d, "*#{mode}*.bin")])
    printf("| %s | %s | %d | %d | %.0f | %s | %.2f / %.1f | %.2f / %.1f |\n", { "bytes" => "master", "slots" => "fix", "pr17251s" => "#17251" }.fetch(v, v), r,
      sum.("major_gc_count"), sum.("minor_gc_count"), sum.("time"), rss, pct(pause, 0.99) / 1e6, pause.last.to_i / 1e6,
      pct(big, 0.99) / 1e6, big.last.to_i / 1e6)
  end
end
