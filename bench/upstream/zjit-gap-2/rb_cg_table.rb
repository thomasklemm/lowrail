# frozen_string_literal: true

# M Ir per iteration for the Z1-2 ruby-bench Callgrind cohort (docs/upstream/zjit-gap-census-2.md).
#   ruby SCRIPT OUT_ROOT
# OUT_ROOT/BENCH/BUILD/MODE-RUN.json from zjit_yjit_gap_harness.rb (bench/upstream/zjit-gap-2/cg_queue.sh); the used dump minus the
# empty window (dump 1), divided by the window's iterations. Prints runs, mean, A/A spread and ZJIT vs YJIT per build.
require "json"

root = ARGV.fetch(0)
ir = lambda do |json|
  d = JSON.parse(File.read(json))
  total = ->(n) { File.foreach(Dir[json.sub(/\.json\z/, ".cg.*.#{n}")].first).grep(/\Atotals: /).first.split.last.to_f }
  [(total.(d["dump"]) - total.(1)) / d["itrs"] / 1e6, d.dig("jit_flat", "gate"), d["attempts"].last["first_itr"], d["attempts"].size]
end

puts "| benchmark | build | YJIT runs | ZJIT runs | A/A YJIT, ZJIT | ZJIT vs YJIT |"
puts "| --- | --- | ---: | ---: | ---: | ---: |"
Dir[File.join(root, "*", "*")].sort.each do |dir|
  bench, build = dir.split("/").last(2)
  runs = Dir[File.join(dir, "*-?.json")].reject { _1.end_with?(".cg.json") }.to_h { [File.basename(_1, ".json"), ir.(_1)] }
  by = ->(mode) { runs.select { |k, _| k.start_with?(mode) }.sort }
  mean = ->(mode) { xs = by.(mode).map { _2[0] }; xs.empty? ? nil : xs.sum / xs.size }
  cell = ->(mode) { by.(mode).map { |k, (v, gate, first, n)| "#{k[-1]} #{format("%.1f", v)}#{gate == "pass" ? "" : " (#{gate})"} @#{first}#{n > 1 ? " ×#{n}" : ""}" }.join(", ") }
  aa = ->(mode) { xs = by.(mode).map { _2[0] }; xs.size > 1 ? format("%.2f%%", 100 * (xs.max - xs.min) / mean.(mode)) : "–" }
  vs = mean.("zjit") && mean.("yjit") ? format("%+.1f%%", 100 * (mean.("zjit") / mean.("yjit") - 1)) : "–"
  puts "| #{bench} | #{build} | #{cell.("yjit")} | #{cell.("zjit")} | #{aa.("yjit")}, #{aa.("zjit")} | **#{vs}** |"
end
