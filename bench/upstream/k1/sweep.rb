# frozen_string_literal: true

# Compact width sweep from run.sh output: ruby sweep.rb DIR MODE
# Fix against main per case and width, with the largest A/A of that width in the header; cells that compiled in a
# measured window (main, main2 or fix) are marked "rej".
require "json"

dir, mode = ARGV
widths = [5, 30, 100, 300]
data = %w[main main2 fix].to_h do |tree|
  [tree, widths.to_h do |w|
    path = File.join(dir, "#{tree}-#{mode}-w#{w}.jsonl")
    [w, File.exist?(path) ? File.readlines(path).to_h { |l| r = JSON.parse(l); [r["case"], r] } : {}]
  end]
end
pct = ->(a, b) { 100.0 * (a - b) / b }
cases = data["main"][5].keys - ["_empty"]
aa = widths.to_h do |w|
  vals = cases.filter_map do |c|
    m, a = data["main"][w][c], data["main2"][w][c]
    pct.(a["ir"], m["ir"]).abs if m && a && m["ir"] > 2000 && m["jit_blocks"].zero? && a["jit_blocks"].zero?
  end
  [w, vals.max]
end
puts "| #{mode} | " + widths.map { |w| "#{w} cols (A/A ≤ #{aa[w] ? format('%.2f%%', aa[w]) : '–'})" }.join(" | ") + " |"
puts "|---|" + widths.map { "---:" }.join("|") + "|"
cases.each do |c|
  cells = widths.map do |w|
    m, a, f = %w[main main2 fix].map { data[_1][w][c] }
    next "–" unless m && f
    rej = [m, a, f].compact.any? { _1["jit_blocks"].positive? }
    format("%+.1f%%%s", pct.(f["ir"], m["ir"]), rej ? " rej" : "")
  end
  puts "| #{c} | #{cells.join(' | ')} |"
end
