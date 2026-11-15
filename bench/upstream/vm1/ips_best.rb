# frozen_string_literal: true

# Best-of-N i/s per report and tree from an ips_matrix.sh output file.
#   ruby ips_best.rb FILE [BASE_LABEL]
cur = nil
inside = false
all = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
File.foreach(ARGV[0]) do |l|
  cur = $1 if l =~ /^== (\S+) round/
  inside = true if l.start_with?("Calculating")
  inside = false if l.start_with?("Warming")
  next unless inside && l =~ /^\s+(\S+)\s+([\d.]+)([kM]) \(/

  all[$1][cur] << $2.to_f * ($3 == "M" ? 1e6 : 1e3)
end
base = ARGV[1] || "base"
all.each do |report, trees|
  best = trees.transform_values(&:max)
  cols = best.map { |t, v| format("%s %.1fk (%.3f µs, n=%d)", t, v / 1e3, 1e6 / v, trees[t].size) }
  diffs = best.except(base).map { |t, v| format("%s/%s %+.1f%%", t, base, 100 * (v / best[base] - 1)) }
  puts "#{report}: #{cols.join(", ")}; #{diffs.join(", ")}"
end
