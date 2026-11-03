# frozen_string_literal: true

# ZJIT combined-effect table for docs/upstream/combined-effect.md (Ruby master pin,
# interpreter and ZJIT; adapted from ../combined_effect/census_table.rb):
#   ruby census_table.rb OUT WITH WITH2 WITHOUT WITHOUT2
# WITH/WITH2 are the A/A pair on Rails main (the PRs merged), WITHOUT/WITHOUT2
# the A/A pair on the same commit with the PRs reverted. Per app and mode:
# objects per workload (mean over workloads of the median GC-enabled objects
# per operation, averaged over each pair), the PRs' delta and its share of the
# reverted tree's total, and both A/A deltas on the same scale.
require "json"
require_relative "../census/compare"

out, with, with2, without, without2 = ARGV
abort "usage: census_table.rb OUT WITH WITH2 WITHOUT WITHOUT2" unless without2
PG = %w[docuseal mastodon mastodon-nops lago lago-nops discourse loomio sure casa codetriage pingcrm].freeze

def load(out, label, file) = CensusCompare.per_workload(out, label, file).transform_values { CensusCompare.median(_1["gc_enabled_objects_per_op"]) }

files = CensusCompare.files(out, with)
rows = files.map do |file|
  app, mode = file.delete_suffix(".json").split(/-(?=interpreter|zjit)/)
  w1, w2, o1, o2 = [with, with2, without, without2].map { load(out, _1, file) }
  names = w1.keys
  raise "#{file}: workload sets differ" unless [w2, o1, o2].all? { _1.keys.sort == names.sort }
  sum = ->(h) { names.sum { h[_1] } }
  per = names.to_h { [_1, (w1[_1] + w2[_1]) / 2.0 - (o1[_1] + o2[_1]) / 2.0] }
  { app:, mode:, n: names.size, with: (sum.(w1) + sum.(w2)) / 2.0, without: (sum.(o1) + sum.(o2)) / 2.0,
    aa_with: sum.(w2) - sum.(w1), aa_without: sum.(o2) - sum.(o1),
    moved: per.count { _2 <= -1.0 }, up: per.count { _2 >= 1.0 }, median: CensusCompare.median(per.values),
    moved_aa: names.count { w2[_1] - w1[_1] <= -1.0 } }
end

pct = ->(d, t) { format("%+.2f%%", 100.0 * d / t).sub("-", "−") }
num = ->(v) { format("%+.1f", v).sub("-", "−") }
# One row per app; "interpreter / ZJIT" in each cell.
puts "| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Workloads moved ≤ −1 (A/A) |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"
rows.group_by { _1[:app] }.sort_by { |app, _| [PG.include?(app) ? 1 : 0, app] }.each do |app, rs|
  i, y = %w[interpreter zjit].map { |m| rs.find { _1[:mode] == m } }
  n = i[:n]
  both = ->(&f) { [i, y].map(&f).join(" / ") }
  puts "| #{app} | #{n} | #{both.() { "#{(_1[:without] / n).round} → #{(_1[:with] / n).round}" }} | " \
    "#{both.() { num.((_1[:with] - _1[:without]) / n) }} | #{both.() { pct.(_1[:with] - _1[:without], _1[:without]) }} | " \
    "#{both.() { "#{pct.(_1[:aa_with], _1[:with])}, #{pct.(_1[:aa_without], _1[:without])}" }} | " \
    "#{both.() { "#{_1[:moved]} (#{_1[:moved_aa]})" }} |"
end
puts
{ "census-4 nine (10 configurations)" => ->(_) { true } }.each do |name, pick|
  %w[interpreter zjit].each do |mode|
    rs = rows.select { _1[:mode] == mode && pick.(_1) }
    n = rs.sum { _1[:n] }
    w = rs.sum { _1[:with] }
    o = rs.sum { _1[:without] }
    aw = rs.sum { _1[:aa_with] }
    ao = rs.sum { _1[:aa_without] }
    puts format("%-52s %-11s workloads %3d  objects/workload %8.1f -> %8.1f  Δ %s (%s)  A/A %s / %s  moved %d (A/A %d)",
      name, mode, n, o / n, w / n, num.((w - o) / n), pct.(w - o, o), pct.(aw, w), pct.(ao, o), rs.sum { _1[:moved] }, rs.sum { _1[:moved_aa] })
  end
end
