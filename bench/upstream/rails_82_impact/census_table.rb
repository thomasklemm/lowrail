# frozen_string_literal: true

# Census allocation table for docs/upstream/rails-82-impact.md, interpreter
# only, over the apps every label ran:
#   ruby census_table.rb OUT NEW NEW2 OLD OLD2
# Per app: objects per workload (mean over workloads of the median GC-enabled
# objects per operation, averaged over each A/A pair), the change from OLD to
# NEW, and both A/A deltas on the same scale. A row is claimed only when
# |Δ| exceeds 2 × the larger A/A delta.
require "json"
require_relative "../census/compare"

out, *labels = ARGV
abort "usage: census_table.rb OUT NEW NEW2 OLD OLD2" unless labels.size == 4

def load(out, label, file) = CensusCompare.per_workload(out, label, file).transform_values { CensusCompare.median(_1["gc_enabled_objects_per_op"]) }

files = CensusCompare.files(out, labels[0]).select { |f| f.end_with?("-interpreter.json") && labels.all? { File.exist?(File.join(out, _1, f)) } }
puts "| App | Workloads | Objects/workload old → new | Δ | Δ % | A/A new, old | Workloads ≤ −1 / ≥ +1 | Verdict |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
files.sort.each do |file|
  n1, n2, o1, o2 = labels.map { load(out, _1, file) }
  names = n1.keys & n2.keys & o1.keys & o2.keys
  dropped = (n1.keys | o1.keys) - names
  sum = ->(h) { names.sum { h[_1] } / names.size.to_f }
  new, old = (sum.(n1) + sum.(n2)) / 2, (sum.(o1) + sum.(o2)) / 2
  aa_n, aa_o = sum.(n2) - sum.(n1), sum.(o2) - sum.(o1)
  per = names.map { (n1[_1] + n2[_1]) / 2.0 - (o1[_1] + o2[_1]) / 2.0 }
  d = new - old
  verdict = d.abs > 2 * [aa_n.abs, aa_o.abs].max ? "claimed" : "rejected (A/A)"
  puts format("| %s | %d%s | %.1f → %.1f | %+.1f | %+.2f%% | %+.2f, %+.2f | %d / %d | %s |",
              file.delete_suffix("-interpreter.json"), names.size, dropped.empty? ? "" : " (#{dropped.size} not in all)",
              old, new, d, 100 * d / old, aa_n, aa_o, per.count { _1 <= -1 }, per.count { _1 >= 1 }, verdict)
end
