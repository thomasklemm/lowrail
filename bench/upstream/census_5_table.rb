# frozen_string_literal: true

# Census 5 per-app delta table: ruby SCRIPT ROOT BASE A_A LABEL...
# Prints a Markdown table of per-app median deltas (LABEL - BASE), interpreter /
# YJIT, with an A/A column (BASE - A_A) and totals over all workloads.
require "json"

root, base, aa, *labels = ARGV
median = ->(a) { a.sort[a.size / 2] }
load = ->(label, app, mode) do
  path = File.join(root, label, "#{app}-#{mode}.json")
  JSON.parse(File.read(path))["workloads"].to_h { [_1["workload"], median.(_1["gc_enabled_objects_per_op"])] }
end
apps = Dir[File.join(root, base, "*-interpreter.json")].map { File.basename(_1).delete_suffix("-interpreter.json") }.sort
columns = [[aa, base]] + labels.map { [base, _1] }
all = Hash.new { |h, k| h[k] = [] }
fmt = ->(v) { format("%+.1f", v).sub("-", "−") }
puts "| App | #{(["A/A"] + labels).join(" | ")} |"
puts "| --- |#{" ---: |" * columns.size}"
apps.each do |app|
  cells = columns.map do |from, to|
    %w[interpreter yjit].map do |mode|
      a = load.(from, app, mode)
      b = load.(to, app, mode)
      d = a.keys.map { (b.fetch(_1) - a.fetch(_1)).round(1) }
      all[[from, to, mode]].concat(d)
      fmt.(median.(d))
    end.join(" / ")
  end
  puts "| #{app} | #{cells.join(" | ")} |"
end
totals = columns.map { |from, to| %w[interpreter yjit].map { fmt.(median.(all[[from, to, _1]])) }.join(" / ") }
puts "| **All workloads** | #{totals.map { "**#{_1}**" }.join(" | ")} |"
moved = columns.map do |from, to|
  %w[interpreter yjit].map { |m| d = all[[from, to, m]]; "#{d.count { _1 <= -1 }} / #{d.count { _1 >= 1 }}" }.join(" · ")
end
puts "| Moved ≤ −1 / ≥ +1 | #{moved.join(" | ")} |"
