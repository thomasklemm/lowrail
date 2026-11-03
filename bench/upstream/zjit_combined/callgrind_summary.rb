# frozen_string_literal: true

# Summary of callgrind.sh output: Ir per iteration (MEASURE_ITRS window minus
# the empty window, over MEASURE_ITRS), GC runs and objects per iteration, per
# app and variant. Per round: with (mean of A and B) over without; A/A is B over
# A within each tree.
#   ruby callgrind_summary.rb OUT
out = ARGV.fetch(0)
total = ->(f) { Integer(File.foreach(f).grep(/\Atotals:/).first.split[1]) }
runs = Dir["#{out}/*.log"].reject { _1.end_with?(".vg.log") }.filter_map do |log|
  name = File.basename(log, ".log")
  app, tree, ab, round = name.match(/\A(\w+)-(with|without)-([AB])-r(\d+)\z/).captures
  next unless File.exist?("#{out}/#{name}.cg.2")
  line = File.read(log)[/CALLGRIND windows 0 (\d+) gc (\d+) objects (\d+)/] or next
  itrs, gc, objects = $1.to_i, $2.to_i, $3.to_i
  abort "brk overflow in #{name}" if File.read("#{out}/#{name}.vg.log").include?("brk segment overflow")
  { app:, tree:, ab:, round: round.to_i, ir: (total.("#{out}/#{name}.cg.2") - total.("#{out}/#{name}.cg.1")).fdiv(itrs),
    gc: gc.fdiv(itrs), objects: objects.fdiv(itrs) }
end
pct = ->(r) { format("%+.2f%%", 100 * (r - 1)).sub("-", "−") }
puts "| App | Rounds | Ir/iter without | Ir/iter with | with / without: mean (range) | A/A with: mean (max abs) | A/A without: mean (max abs) | GC/iter without → with | objects/iter without → with |"
puts "| --- | ---: | ---: | ---: | --- | --- | --- | --- | --- |"
runs.group_by { _1[:app] }.sort.each do |app, rs|
  rounds = rs.group_by { _1[:round] }.select { _2.size == 4 }.sort.map(&:last)
  get = ->(r, t, ab) { r.find { _1[:tree] == t && _1[:ab] == ab } }
  ratio = rounds.map { |r| (get.(r, "with", "A")[:ir] + get.(r, "with", "B")[:ir]) / (get.(r, "without", "A")[:ir] + get.(r, "without", "B")[:ir]) }
  aa = %w[with without].to_h { |t| [t, rounds.map { |r| get.(r, t, "B")[:ir] / get.(r, t, "A")[:ir] }] }
  mean = ->(a) { a.sum / a.size }
  tree = ->(t, k) { mean.(rs.select { _1[:tree] == t }.map { _1[k] }) }
  maxabs = ->(a) { a.max_by { (_1 - 1).abs } }
  puts "| #{app} | #{rounds.size} | #{format("%.4g", tree.("without", :ir))} | #{format("%.4g", tree.("with", :ir))} | " \
    "#{pct.(mean.(ratio))} (#{pct.(ratio.min)} … #{pct.(ratio.max)}) | #{pct.(mean.(aa["with"]))} (#{pct.(maxabs.(aa["with"]))}) | " \
    "#{pct.(mean.(aa["without"]))} (#{pct.(maxabs.(aa["without"]))}) | #{format("%.2f → %.2f", tree.("without", :gc), tree.("with", :gc))} | " \
    "#{format("%.0f → %.0f (%s)", tree.("without", :objects), tree.("with", :objects), pct.(tree.("with", :objects) / tree.("without", :objects)))} |"
end
