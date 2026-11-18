# frozen_string_literal: true

# Round 3 table for docs/upstream/combined-effect.md (from ../combined_effect/census_table.rb, with the modes
# as a parameter, a total row and the workloads that rise):
#   ruby census_table.rb OUT MODES WITH WITH2 WITHOUT WITHOUT2
# MODES is "interpreter,yjit" or "interpreter,zjit". WITH/WITH2 are the A/A pair of the tree with our changes,
# WITHOUT/WITHOUT2 the pair with them reverted. Per app and mode: objects per workload (mean over workloads of
# the median GC-enabled objects per operation, averaged over each pair), the change and its share of the
# reverted tree's total, both A/A changes on the same scale, and the workloads that move by at least one object
# (A/A: WITH2 against WITH).
require "json"
require_relative "../census/compare"

out, modes, with, with2, without, without2 = ARGV
abort "usage: census_table.rb OUT MODES WITH WITH2 WITHOUT WITHOUT2" unless without2
modes = modes.split(",")

def load(out, label, file) = CensusCompare.per_workload(out, label, file).transform_values { CensusCompare.median(_1["gc_enabled_objects_per_op"]) }

rows = CensusCompare.files(out, with).filter_map do |file|
  app, mode = file.delete_suffix(".json").split(/-(?=interpreter|yjit|zjit)/)
  next unless modes.include?(mode)
  w1, w2, o1, o2 = [with, with2, without, without2].map { load(out, _1, file) }
  names = w1.keys
  raise "#{file}: workload sets differ" unless [w2, o1, o2].all? { _1.keys.sort == names.sort }
  sum = ->(h) { names.sum { h[_1] } }
  per = names.to_h { [_1, (w1[_1] + w2[_1]) / 2.0 - (o1[_1] + o2[_1]) / 2.0] }
  { app:, mode:, n: names.size, with: (sum.(w1) + sum.(w2)) / 2.0, without: (sum.(o1) + sum.(o2)) / 2.0,
    aa_with: sum.(w2) - sum.(w1), aa_without: sum.(o2) - sum.(o1),
    down: per.count { _2 <= -1.0 }, up: per.count { _2 >= 1.0 },
    down_aa: names.count { w2[_1] - w1[_1] <= -1.0 }, up_aa: names.count { w2[_1] - w1[_1] >= 1.0 } }
end

pct = ->(d, t) { format("%+.2f%%", 100.0 * d / t).sub("-", "−") }
num = ->(v) { format("%+.1f", v).sub("-", "−") }
cells = lambda do |rs, n|
  both = ->(&f) { rs.map(&f).join(" / ") }
  [n, both.() { "#{(_1[:without] / n).round} → #{(_1[:with] / n).round}" }, both.() { num.((_1[:with] - _1[:without]) / n) },
   both.() { pct.(_1[:with] - _1[:without], _1[:without]) },
   both.() { "#{pct.(_1[:aa_with], _1[:with])}, #{pct.(_1[:aa_without], _1[:without])}" },
   both.() { "#{_1[:down]} (#{_1[:down_aa]})" }, both.() { "#{_1[:up]} (#{_1[:up_aa]})" }]
end
puts "#{modes.join(" / ")} in every cell."
puts
puts "| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Moved ≤ −1 (A/A) | Moved ≥ +1 (A/A) |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
rows.group_by { _1[:app] }.sort.each do |app, rs|
  rs = modes.map { |m| rs.find { _1[:mode] == m } }
  puts "| #{app} | #{cells.(rs, rs.first[:n]).join(" | ")} |"
end
total = modes.map do |m|
  rs = rows.select { _1[:mode] == m }
  %i[n with without aa_with aa_without down up down_aa up_aa].to_h { |k| [k, rs.sum { _1[k] }] }
end
puts "| **All #{rows.map { _1[:app] }.uniq.size} apps** | #{cells.(total, total.first[:n]).join(" | ")} |"
