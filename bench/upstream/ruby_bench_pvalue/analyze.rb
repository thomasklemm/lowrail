# Usage: ruby analyze.rb RUNS file.json...
# Each file holds K identical executables (A/A). Reports:
#  before: Welch over iterations of one process, for every pair and for disjoint pairs
#  after:  Welch over per-process means, A and B = random disjoint groups of RUNS processes
require 'json'
# RUBY_BENCH: a ruby-bench checkout (its misc/stats.rb has Stats.welch_p_value)
require File.join(ENV.fetch('RUBY_BENCH'), 'misc/stats')

runs = Integer(ARGV.shift)
rng = Random.new(1)
before_all = Hash.new { |h, k| h[k] = [0, 0] }
before_disj = Hash.new { |h, k| h[k] = [0, 0] }
after = Hash.new { |h, k| h[k] = [0, 0] }
spread = Hash.new { |h, k| h[k] = [] }
within = Hash.new { |h, k| h[k] = [] }

ARGV.each do |path|
  raw = JSON.parse(File.read(path))['raw_data']
  names = raw.keys
  benches = raw.values.first.keys
  benches.each do |b|
    series = names.map { |n| raw[n][b]['bench'] }
    mode = names.first[/[a-z]+/]
    key = "#{b} #{mode}"
    means = series.map { |s| s.sum / s.size }
    spread[key] << means
    series.each { |s| within[key] << Stats.new(s).stddev / Stats.new(s).mean * 100 }
    series.combination(2).each { |x, y| before_all[key][1] += 1; before_all[key][0] += 1 if Stats.welch_p_value(x, y) < 0.05 }
    series.each_slice(2) { |x, y| next unless y; before_disj[key][1] += 1; before_disj[key][0] += 1 if Stats.welch_p_value(x, y) < 0.05 }
    200.times do
      idx = (0...means.size).to_a.shuffle(random: rng)
      a = idx[0, runs].map { |i| means[i] }
      c = idx[runs, runs].map { |i| means[i] }
      after[key][1] += 1
      after[key][0] += 1 if Stats.welch_p_value(a, c) < 0.05
    end
  end
end

pct = ->((s, n)) { "%d/%d (%.0f%%)" % [s, n, 100.0 * s / n] }
puts "| bench | process-mean CV | median within-process stddev | before: all pairs | before: disjoint pairs | after, --runs #{runs} (random splits) |"
puts "|---|---:|---:|---:|---:|---:|"
before_all.keys.sort.each do |k|
  m = spread[k].flatten
  mean = m.sum / m.size
  cv = Math.sqrt(m.sum { |v| (v - mean)**2 } / (m.size - 1)) / mean * 100
  w = within[k].sort[within[k].size / 2]
  puts "| #{k} | #{"%.2f%%" % cv} | #{"%.2f%%" % w} | #{pct[before_all[k]]} | #{pct[before_disj[k]]} | #{pct[after[k]]} |"
end
tot = ->(h) { h.values.transpose.map(&:sum) }
puts "| all | | | #{pct[tot[before_all]]} | #{pct[tot[before_disj]]} | #{pct[tot[after]]} |"
