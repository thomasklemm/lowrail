# frozen_string_literal: true

# Summarizes wall_rounds.rb's runs.jsonl: per app, the median of each round's ratios info / a and info / a2
# (the change) and a2 / a (the A/A), with seeded 95% percentile-bootstrap intervals over whole rounds, as
# script/upstream-bench's wall cohort does. A change counts only with at least 10 rounds, an A/A interval that
# contains 0 and a change interval that doesn't.
#   ruby wall_summary.rb OUT_DIR/runs.jsonl [wall|cpu]
require "json"

path, metric = ARGV[0], (ARGV[1] || "wall")
runs = File.readlines(path).map { JSON.parse(_1) }
median = ->(xs) { s = xs.sort; s.empty? ? nil : (s[(s.size - 1) / 2] + s[s.size / 2]) / 2.0 }
pct = ->(x) { x && format("%+.2f%%", (x - 1) * 100) }
rng = Random.new(42)
boot = lambda do |rounds, f|
  stats = Array.new(2000) { f.(Array.new(rounds.size) { rounds[rng.rand(rounds.size)] }) }.sort
  [stats[(0.025 * stats.size).floor], stats[(0.975 * stats.size).ceil - 1]]
end
puts "| App | Rounds | Tests | #{metric} a (median s) | A/A a2/a | 95% | info/a | 95% | Counts |"
puts "| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- |"
runs.group_by { _1["app"] }.each do |app, rs|
  rounds = rs.group_by { _1["round"] }.values.filter_map do |r|
    by = r.to_h { [_1["arm"], _1] }
    next unless %w[a a2 info].all? { by[_1]&.dig(metric) }
    by.transform_values { _1[metric] }
  end
  aa = ->(rr) { median.(rr.map { _1["a2"] / _1["a"] }) }
  ch = ->(rr) { median.(rr.flat_map { [_1["info"] / _1["a"], _1["info"] / _1["a2"]] }) }
  aa_i, ch_i = boot.(rounds, aa), boot.(rounds, ch)
  counts = rounds.size >= 10 && aa_i[0] <= 1 && aa_i[1] >= 1 && (ch_i[1] < 1 || ch_i[0] > 1)
  tests = rs.map { _1["tests"] }.uniq.join("/")
  puts "| #{app} | #{rounds.size} | #{tests} | #{median.(rounds.map { _1["a"] }).round(2)} | #{pct.(aa.(rounds))} | " \
    "#{pct.(aa_i[0])} to #{pct.(aa_i[1])} | #{pct.(ch.(rounds))} | #{pct.(ch_i[0])} to #{pct.(ch_i[1])} | #{counts ? "yes" : "no"} |"
end
