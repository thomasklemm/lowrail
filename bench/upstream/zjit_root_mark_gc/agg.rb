# usage: ruby agg.rb round*.json
# Per executable and benchmark: mean of each run's measured iterations, then
# mean and min..max of those run means across rounds, plus the per-iteration sd.
require "json"

FIELDS = {
  "iter ms"   => ->(d) { d["bench"].map { |t| t * 1000.0 } },
  "mark ms"   => ->(d) { d["gc_marking_time_bench"] },
  "sweep ms"  => ->(d) { d["gc_sweeping_time_bench"] },
  "GC total ms" => ->(d) { d["gc_total_time_bench"] },
  "GCs"       => ->(d) { d["gc_count_bench"] },
  "minor"     => ->(d) { d["gc_minor_count_bench"] },
  "major"     => ->(d) { d["gc_major_count_bench"] },
}

runs = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
ARGV.each do |f|
  JSON.parse(File.read(f))["raw_data"].each do |exe, benches|
    benches.each { |bench, d| runs[bench][exe] << d }
  end
end

mean = ->(a) { a.sum.to_f / a.size }
sd = ->(a) { m = mean.(a); Math.sqrt(a.sum { |x| (x - m)**2 } / [a.size - 1, 1].max) }

runs.sort.each do |bench, exes|
  puts "## #{bench}"
  base = exes["base"]
  exes.keys.sort_by { |e| %w[base base2 patch].index(e) || 9 }.each do |exe|
    ds = exes[exe]
    puts "### #{exe} (#{ds.size} runs, #{ds.map { |d| d['bench'].size }.sum} measured iterations)"
    FIELDS.each do |name, f|
      vals = ds.map { |d| f.(d) }
      next if vals.any?(&:nil?)
      rm = vals.map(&mean)
      all = vals.flatten
      line = "%-12s mean %9.2f  run means %9.2f..%9.2f  per-iter sd %8.2f" % [name, mean.(rm), rm.min, rm.max, sd.(all)]
      if exe != "base" && base
        bm = mean.(base.map { |d| mean.(f.(d)) })
        line << "  vs base %+6.2f%%" % ((mean.(rm) / bm - 1) * 100) if bm != 0
      end
      puts line
    end
    # Iterations with minor GCs only: mark ms per minor GC, without major-GC noise.
    pm = ds.map do |d|
      its = d["gc_major_count_bench"].each_index.select { |i| d["gc_major_count_bench"][i] == 0 && d["gc_minor_count_bench"][i] > 0 }
      [its.sum { |i| d["gc_marking_time_bench"][i] }, its.sum { |i| d["gc_minor_count_bench"][i] }, its.size]
    end
    runs_pm = pm.map { |m, n, _| n > 0 ? m.to_f / n : nil }.compact
    tot_m = pm.sum { |m, _, _| m }; tot_n = pm.sum { |_, n, _| n }
    puts "%-12s %7.3f ms per minor GC over %d minor GCs in %d minor-only iterations; per-run %s" %
      ["mark/minor", tot_n > 0 ? tot_m.to_f / tot_n : 0, tot_n, pm.sum { |*, k| k }, runs_pm.map { |x| "%.3f" % x }.join(" ")]
  end
  puts
end
