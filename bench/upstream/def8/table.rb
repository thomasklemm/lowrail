# frozen_string_literal: true

# Ablation table from ir.sh rows: what each piece costs per request, as base
# minus the run with that piece off (Ir and objects), with the A/A beside it:
#   ruby table.rb IR.tsv [MODE]
rows = File.readlines(ARGV[0], chomp: true).map { _1.split("\t") }
mode = ARGV[1] || "interp"
rows = rows.select { _1[2] == mode }
cells = rows.to_h { |app, label, _, workload, ir, objects, blocks| [[label, workload], [Integer(ir), Integer(objects), Integer(blocks)]] }
workloads = rows.map { _1[3] }.uniq
labels = rows.map { _1[1] }.uniq - %w[base base-aa]
base = workloads.to_h { |w| [w, cells.fetch(["base", w])] }
fmt = ->(ir, total) { format("%+.2f%%", 100.0 * ir / total) }
puts "| piece | #{workloads.join(" | ")} |"
puts "|---|#{"---:|" * workloads.size}"
puts "| base Ir (objects) | #{workloads.map { |w| "#{base[w][0].to_s.reverse.scan(/\d{1,3}/).join(",").reverse} (#{base[w][1]})" }.join(" | ")} |"
aa = workloads.map do |w|
  a = cells[["base-aa", w]] or next "–"
  "#{fmt.(a[0] - base[w][0], base[w][0])} (#{a[1] - base[w][1]})"
end
puts "| A/A | #{aa.join(" | ")} |"
ranked = labels.sort_by { |l| workloads.sum { |w| (c = cells[[l, w]]) ? c[0] - base[w][0] : 0 } }
ranked.each do |label|
  row = workloads.map do |w|
    c = cells[[label, w]] or next "–"
    flag = c[2] > 0 && mode == "yjit" ? " ⚠#{c[2]}" : ""
    "#{fmt.(base[w][0] - c[0], base[w][0])} (#{base[w][1] - c[1]})#{flag}"
  end
  puts "| #{label} | #{row.join(" | ")} |"
end
