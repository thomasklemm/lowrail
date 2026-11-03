# frozen_string_literal: true

# ns_best.rb OUT: best (minimum) ns per call per case, mode and variant from ns.sh output, with the A/A
# (aa against main) and the candidate (cand against main) in percent.
best = Hash.new { |h, k| h[k] = Float::INFINITY }
File.foreach(ARGV.fetch(0)) do |line|
  _round, variant, kase, mode, ns = line.split
  key = [kase, mode, variant]
  best[key] = [best[key], Float(ns)].min
end
pct = ->(a, b) { format("%+.1f%%", (a / b - 1) * 100) }
puts "case\tmode\tmain\taa\tcand\taa_vs_main\tcand_vs_main"
best.keys.map { |k| k[0, 2] }.uniq.sort.each do |kase, mode|
  m, a, c = %w[main aa cand].map { |v| best[[kase, mode, v]] }
  puts [kase, mode, m.round, a.round, c.round, pct.(a, m), pct.(c, m)].join("\t")
end
