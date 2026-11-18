# frozen_string_literal: true

# method_share.rb DIR LABEL PATTERN... : per workload of a script/cpu-census label (interpreter,
# JIT-flat), the self and inclusive Ir per op of the Rails methods whose "file method" matches any
# PATTERN (a Regexp), as a share of the workload's Ir per op. Inclusive shares of nested methods
# overlap, so the summary uses the largest single inclusive share per workload.
require "json"
dir, label, *patterns = ARGV
re = Regexp.union(patterns.map { Regexp.new(_1) })
rows = []
Dir[File.join(dir, label, "*-interpreter.json")].sort.each do |path|
  run = JSON.parse(File.read(path))
  run["workloads"].each do |w|
    next unless w.fetch("jit_flat", true)
    hit = w["methods"].select { |m| "#{m["file"]} #{m["method"]}".match?(re) }
    self_ir = hit.sum { _1["self_ir_per_op"] }
    incl = hit.map { _1["incl_ir_per_op"] }.max || 0
    rows << [run["app"], w["workload"], w["ir_per_op"], self_ir, incl]
  end
end
puts "app\tworkload\tIr/op\tself\tself%\tmax incl%"
rows.each do |app, wl, total, s, i|
  puts [app, wl, total.round, s.round, format("%.3f%%", 100 * s / total), format("%.3f%%", 100 * i / total)].join("\t")
end
shares = rows.map { 100 * _4 / _3 }.sort
reached = shares.count(&:positive?)
all = rows.sum { _4 } / rows.sum { _3 } * 100
puts format("# %d of %d workloads; self share median %.3f%%, max %.3f%%; of all Ir %.3f%%",
  reached, rows.size, shares[shares.size / 2], shares.last, all)
