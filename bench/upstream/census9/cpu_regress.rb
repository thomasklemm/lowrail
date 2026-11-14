# frozen_string_literal: true

# cpu_regress.rb DIR BASE HEAD [--by method|line|name|file] [--min IR] [--limit N]
#
# Rails methods (or lines, or files) whose self instructions per operation
# grew from BASE to HEAD in script/cpu-census labels, with an A/A pair on each
# side (BASE, BASE2, HEAD, HEAD2; interpreter, JIT-flat workloads only). A
# (key, workload) cell moved when all four head x base deltas exceed the cell's
# floor (the larger A/A difference of the two pairs, at least --min, default
# 1,000 Ir) in the same direction, as in main_regressions/method_diff.rb.
#
# Per key: apps and workloads where it grew; the mean growth per op; the mean
# and largest growth as a share of the workload's BASE instructions; the summed
# growth as a share of all BASE instructions of all workloads ("% all"), and
# the same for shrinking. "new" marks keys with no instructions in BASE.
require "json"

dir, base, head = ARGV.first(3)
by = ARGV[ARGV.index("--by") + 1] if ARGV.include?("--by")
by ||= "method"
min = ARGV.include?("--min") ? Float(ARGV[ARGV.index("--min") + 1]) : 1000.0
limit = ARGV.include?("--limit") ? Integer(ARGV[ARGV.index("--limit") + 1]) : 40
mode = ENV.fetch("MODE", "interpreter")

def key_for(by, file, label, line)
  case by
  when "line" then "#{file}:#{line}"
  when "file" then file
  when "name" then label[/[#.][^#.\s]+\z/] || label
  else "#{file} #{label}"
  end
end

# label -> { key => { [app, workload] => self Ir/op } }, and [app, workload] -> total Ir/op
def load(dir, label, mode, by)
  cells = Hash.new { |h, k| h[k] = Hash.new(0.0) }
  totals = {}
  Dir[File.join(dir, label, "*-#{mode}.json")].each do |path|
    run = JSON.parse(File.read(path))
    app = run["app"].sub(/-(mysql|nops)\z/, "")
    run["workloads"].each do |w|
      next unless w.fetch("jit_flat", true)
      wk = [app, w["workload"]]
      totals[wk] = w["ir_per_op"]
      list = by == "line" ? w["sites"] : w["methods"]
      list.each do |m|
        next unless m["file"].start_with?("RAILS/")
        file = m["file"].delete_prefix("RAILS/")
        cells[key_for(by, file, m["method"].to_s, m["line"])][wk] += m.fetch("self_ir_per_op") { m["ir_per_op"] }
      end
    end
  end
  [cells, totals]
end

labels = [base, "#{base}2", head, "#{head}2"].map { load(dir, _1, mode, by) }
totals = labels.map(&:last)
workloads = totals.map(&:keys).reduce(:&)
base_total = workloads.sum { |wk| (totals[0][wk] + totals[1][wk]) / 2 }
rows = labels.flat_map { _1.first.keys }.uniq.filter_map do |key|
  b1, b2, h1, h2 = labels.map { _1.first.fetch(key, {}) }
  grew, shrank = [], []
  workloads.each do |wk|
    vb1, vb2, vh1, vh2 = [b1, b2, h1, h2].map { _1.fetch(wk, 0.0) }
    floor = [(vb1 - vb2).abs, (vh1 - vh2).abs, min].max
    deltas = [vh1 - vb1, vh1 - vb2, vh2 - vb1, vh2 - vb2]
    d = ((vh1 + vh2) - (vb1 + vb2)) / 2
    share = d / ((totals[0][wk] + totals[1][wk]) / 2)
    if deltas.all? { _1 > floor } then grew << [wk, d, share]
    elsif deltas.all? { _1 < -floor } then shrank << [wk, d, share]
    end
  end
  next if grew.empty? && shrank.empty?
  fresh = workloads.all? { |wk| b1.fetch(wk, 0.0).zero? && b2.fetch(wk, 0.0).zero? }
  { key:, grew:, shrank:, fresh:, grew_apps: grew.map { _1[0][0] }.uniq, shrank_apps: shrank.map { _1[0][0] }.uniq }
end

puts "# #{by}, #{mode}: #{base} -> #{head}; #{workloads.size} workloads in all four labels; floor = max(A/A, #{min.round} Ir)"
puts "# apps wl  mean d Ir/op  mean%  max%   %all | apps wl  mean d   %all | key"
fmt = lambda do |list|
  return [0, 0, 0.0, 0.0, 0.0, 0.0] if list.empty?
  [list.map { _1[0][0] }.uniq.size, list.size, list.sum { _1[1] } / list.size, list.sum { _1[2] } / list.size * 100,
    list.map { _1[2].abs }.max * 100, list.sum { _1[1] } / base_total * 100]
end
rows.sort_by { |r| [-r[:grew_apps].size, -r[:grew].sum { _1[1] }] }.first(limit).each do |r|
  ga, gw, gm, gs, gx, gt = fmt.(r[:grew])
  sa, sw, sm, _, _, st = fmt.(r[:shrank])
  printf("%2d %3d %+12.0f %5.2f %5.2f %+6.3f | %2d %3d %+9.0f %+6.3f | %s%s\n", ga, gw, gm, gs, gx, gt, sa, sw, sm, st, r[:key], r[:fresh] ? " (new)" : "")
end
