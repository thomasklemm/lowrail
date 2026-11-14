# ruby gc_census_report.rb CENSUS_ROOT STEPS_ROOT ROUND... -- GC pool-budget census cells (gc_census.sh):
# CENSUS_ROOT/gc{bytes,slots,17251}-R/APP-yjit.json (gc_long per workload) and STEPS_ROOT/{bytes,slots}-R/*.bin
# (gcstep.patch step logs, record format as in gc_report.rb; the plain ruby/ruby#17251 build has none, 17251s is it with gcstep.patch). Sums over every workload's long GC window.
require "json"
root, steps, *rounds = ARGV
def pct(a, q) = a.empty? ? 0 : a[[(a.size * q).ceil - 1, 0].max]
puts "| build | round | majors | minors | GC ms | RSS growth MB | sweep pause p99 / max ms | large-slot step p99 / max ms |"
puts "|---|---|---:|---:|---:|---:|---:|---:|"
(ENV["VARIANTS"] || "bytes slots 17251 17251s").split.each do |v|
  rounds.each do |r|
    ws = Dir[File.join(root, "gc#{v}-#{r}", "*-yjit.json")].flat_map { JSON.parse(File.read(_1))["workloads"] }
    next if ws.empty?
    sum = ->(k) { ws.sum { |w| w.dig("gc_long", k).to_f } }
    pause = []; big = []
    Dir[File.join(steps, "#{v}-#{r}", "*.bin")].each do |f|
      d = File.binread(f)
      (d.bytesize / 24).times do |i|
        ns, _p, _s, _f, ss, ctx, _h = d.byteslice(i * 24, 24).unpack("Q<L<L<L<S<CC")
        pause << ns if ctx == 8
        big << ns if ctx == 1 && ss >= 512
      end
    end
    pause.sort!; big.sort!
    step = ->(a) { a.empty? ? "–" : format("%.2f / %.1f", pct(a, 0.99) / 1e6, a.last / 1e6) }
    printf("| %s | %s | %d | %d | %.0f | %+.1f | %s | %s |\n", { "bytes" => "master", "slots" => "fix", "17251" => "#17251", "17251s" => "#17251 gcstep" }[v], r,
      sum.("major_gc_count"), sum.("minor_gc_count"), sum.("time"), sum.("rss_kb_growth") / 1024.0, step.(pause), step.(big))
  end
end
