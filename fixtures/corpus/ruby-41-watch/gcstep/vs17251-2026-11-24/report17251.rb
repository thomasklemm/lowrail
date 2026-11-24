# ruby report17251.rb -- shipit (~/w/gcrb/V-R/shipit-MODE.json + .bin) and census
# (.lowrail/private/census/gcV-R/APP-MODE.json, steps ~/w/gcsteps/V-R/*.bin) for V in master old new.
# Step record as in fixtures/corpus/ruby-master-round-2/gc_report.rb.
require "json"
CENSUS = "/home/user/workspace/repo/.lowrail/private/census"
NAMES = { "master" => "master", "old" => "old head 41c689571a", "new" => "new head 57eb4b4274" }
def pct(a, q) = a.empty? ? 0 : a[[(a.size * q).ceil - 1, 0].max]
def steps(files)
  pause = []; big = []
  files.each do |f|
    d = File.binread(f)
    (d.bytesize / 24).times do |i|
      ns, _p, _s, _f, ss, ctx, _h = d.byteslice(i * 24, 24).unpack("Q<L<L<L<S<CC")
      pause << ns if ctx == 8
      big << ns if ctx == 1 && ss >= 512
    end
  end
  [pause.sort, big.sort]
end
fmt = ->(a) { a.empty? ? "–" : format("%.2f / %.1f", pct(a, 0.99) / 1e6, a.last / 1e6) }
puts "## shipit"
puts "| mode | build | round | majors | minors | GC ms | peak RSS MB | sweep pause p99 / max ms | large-slot step p99 / max ms |"
puts "|---|---|---|---:|---:|---:|---:|---:|---:|"
%w[interp yjit].each do |mode|
  NAMES.each do |v, name|
    %w[a b c].each do |r|
      f = File.expand_path("~/w/gcrb/#{v}-#{r}/shipit-#{mode}.json")
      next unless File.exist?(f)
      j = JSON.parse(File.read(f))
      pause, big = steps(Dir[File.expand_path("~/w/gcrb/#{v}-#{r}/shipit-#{mode}*.bin")])
      printf("| %s | %s | %s | %d | %d | %.0f | %.0f | %s | %s |\n", mode, name, r, j["major_gc_count"], j["minor_gc_count"],
        j["time"], j["rss_kb_peak"] / 1024.0, fmt.(pause), fmt.(big))
    end
  end
end
puts "\n## census"
puts "| mode | build | round | workloads | majors (nofree) | minors | GC ms | RSS growth MB | sweep pause p99 / max ms | large-slot step p99 / max ms | heaps forcing majors |"
puts "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|"
%w[interpreter yjit].each do |mode|
  NAMES.each do |v, name|
    %w[a b c].each do |r|
      ws = Dir[File.join(CENSUS, "gc#{v}-#{r}", "*-#{mode}.json")].flat_map { JSON.parse(File.read(_1))["workloads"] }
      next if ws.empty?
      sum = ->(k) { ws.sum { |w| w.dig("gc_long", k).to_f } }
      nofree = ws.sum { |w| w.dig("gc_long", "major_by", "nofree").to_i }
      forced = Hash.new(0)
      ws.each { |w| (w.dig("gc_long", "forced_major_by_slot") || {}).each { |s, n| forced[s.to_i] += n } }
      forced = forced.select { _2 > 0 }.sort.map { "#{_1} B #{_2}" }.join(", ")
      pause, big = steps(Dir[File.expand_path("~/w/gcsteps/#{v}-#{r}/*#{mode == "interpreter" ? "interp" : mode}*.bin")])
      printf("| %s | %s | %s | %d | %d (%d) | %d | %.0f | %+.1f | %s | %s | %s |\n", mode == "interpreter" ? "interp" : mode, name, r, ws.size,
        sum.("major_gc_count"), nofree, sum.("minor_gc_count"), sum.("time"), sum.("rss_kb_growth") / 1024.0, fmt.(pause), fmt.(big),
        forced.empty? ? "none" : forced)
    end
  end
end
