# frozen_string_literal: true

# site_reach.rb DIR LABEL FILE:LINE... : objects per op that a script/census label allocates at
# the given Rails lines, per workload (interpreter), with the workload's total objects per op.
# Census 10 uses it for the owner-condition lines (where_clause.rb:22, association_scope.rb:68).
require "json"
dir, label, *keys = ARGV
rows = []
Dir[File.join(dir, label, "*-interpreter.json")].sort.each do |path|
  run = JSON.parse(File.read(path))
  run["workloads"].each do |w|
    hits = keys.to_h { [_1, 0.0] }
    w["sites"].each do |s|
      k = "#{s["file"].delete_prefix("RAILS/")}:#{s["line"]}"
      keys.each { |want| hits[want] += s["objects_per_op"] if k.end_with?(want) }
    end
    total = w["gc_enabled_objects_per_op"].sum / w["gc_enabled_objects_per_op"].size
    rows << [run["app"], w["workload"], total, hits]
  end
end
puts "app\tworkload\tobjects/op\t#{keys.join("\t")}\tshare"
rows.each do |app, wl, total, hits|
  sum = hits.values.sum
  puts [app, wl, total.round, *hits.values.map { _1.round(1) }, format("%.2f%%", 100 * sum / total)].join("\t")
end
reached = rows.count { |*, h| h.values.sum.positive? }
puts "# #{reached} of #{rows.size} workloads reach these lines"
