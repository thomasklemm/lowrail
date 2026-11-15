# frozen_string_literal: true

# Summarizes N rounds of run_benchmarks.rb (master, master-aa, branch) for docs/upstream/zjit-not-equal.md.
#   ruby rounds.rb ROUND1.json ROUND2.json ...
# Per round: mean ratios master/master-aa and master/branch per benchmark, and the round's A/A distance
# (sum of |log(master/master-aa)|). The quietest round is the one with the smallest distance; that choice
# does not look at the branch. Then the best of N: the fastest iteration per executable over all rounds.
require "json"

rounds = ARGV.map { JSON.parse(File.read(_1)).fetch("raw_data") }
benches = rounds.first.fetch("master").keys.sort
mean = ->(list) { list.sum / list.size }
times = ->(round, exe, bench) { round.fetch(exe).fetch(bench).fetch("bench") }

distances = rounds.each_with_index.map do |round, i|
  cells = benches.map do |bench|
    master = mean.(times.(round, "master", bench))
    aa = master / mean.(times.(round, "master-aa", bench))
    branch = master / mean.(times.(round, "branch", bench))
    [bench, aa, branch]
  end
  distance = cells.sum { |_, aa, _| Math.log(aa).abs }
  puts "round #{i + 1}: A/A distance #{distance.round(3)}"
  cells.each { |bench, aa, branch| puts format("  %-15s master/master-aa %.3f  master/branch %.3f", bench, aa, branch) }
  distance
end
puts "quietest round: #{distances.index(distances.min) + 1}"

puts "best of #{rounds.size} (fastest iteration, ms):"
benches.each do |bench|
  best = %w[master master-aa branch].to_h { |exe| [exe, rounds.flat_map { times.(_1, exe, bench) }.min * 1000] }
  puts format("  %-15s master %.1f  master-aa %.1f  branch %.1f  master/master-aa %.3f  master/branch %.3f",
    bench, best["master"], best["master-aa"], best["branch"], best["master"] / best["master-aa"], best["master"] / best["branch"])
end
