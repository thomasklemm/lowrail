# Hash allocations at lines where master allocates about twice 4.0.7's count: the kwsplat family.
require "json"
norm = ->(f) { f.sub(%r{\AGEM/[^/]+/(bundler/)?gems/}, "GEM/") }
mode = ARGV[0]
tot = Hash.new(0.0); lines = Hash.new(0.0); per = []
Dir["r407a/*-#{mode}.json"].sort.each do |f|
  o = JSON.parse(File.read(f)); n = JSON.parse(File.read(f.sub("r407a", "rmasa").sub("-#{mode}", "-#{ARGV[1] || mode}")))
  o["workloads"].zip(n["workloads"]).each do |wo, wn|
    agg = ->(w) { h = Hash.new(0.0); w["sites"].each { |s| h["#{norm.(s["file"])}:#{s["line"]}"] += s["objects_per_op"] if s["class"] == "Hash" }; h }
    a = agg.(wo); b = agg.(wn)
    extra = a.sum { |k, v| (v >= 1 && (b[k] - 2 * v).abs <= 0.1 * v) ? (lines[k] += v; v) : 0 }
    per << [o["app"], wo["workload"], extra]
  end
end
ex = per.map(&:last)
puts "workloads with extra kwsplat Hashes: #{ex.count { _1 >= 1 }}/#{ex.size}; apps: #{per.select { _1[2] >= 1 }.map { _1[0].sub(/-mysql/, "") }.uniq.size}; median #{ex.sort[ex.size / 2]}; max #{ex.max}; mean #{(ex.sum / ex.size).round(1)}"
lines.sort_by { -_2 }.first(15).each { |k, v| printf("  %8.1f  %s\n", v, k) }
