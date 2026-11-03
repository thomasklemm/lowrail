# frozen_string_literal: true

# Census 8 vs census 7: the CPU top list (cpu_rank.rb line TSV) against census
# 7's allocation top list (rank-c72-MODE.tsv from its receipts), by site.
#   ruby c7_compare.rb CPU_TSV C7_TSV [TOP]
# Prints the CPU top TOP with each site's census 7 allocation rank, then the
# census 7 top TOP with each site's CPU rank, and the overlap.
require "csv"

cpu_tsv, c7_tsv, top = ARGV
top = Integer(top || 30)
read = ->(path) { CSV.read(path, col_sep: "\t", headers: true, quote_char: "\u0000").map(&:to_h) }
cpu = read.(cpu_tsv)
c7 = read.(c7_tsv)
cpu_rank = cpu.each_with_index.to_h { |row, i| [row["site"], i + 1] }
c7_rank = c7.each_with_index.to_h { |row, i| [row["site"], i + 1] }
cpu_row = cpu.to_h { [_1["site"], _1] }

puts "CPU top #{top} (census 8) with census 7 allocation rank"
puts "| CPU | site | apps | Ir/op | % Ir | obj/op (c8) | c7 alloc rank |"
puts "|---:|---|---:|---:|---:|---:|---:|"
cpu.first(top).each_with_index do |row, i|
  puts "| #{i + 1} | `#{row["site"]}` | #{row["apps"]} | #{Integer(Float(row["mean_ir_per_op"]))} | " \
    "#{format("%.2f", Float(row["pct_of_all_ir"]))} | #{row["objects_per_op"]} | #{c7_rank[row["site"]] || "-"} |"
end
puts
puts "Census 7 allocation top #{top} with census 8 CPU rank"
puts "| c7 | site | apps (c7) | obj/op (c7) | CPU rank | Ir/op | % Ir |"
puts "|---:|---|---:|---:|---:|---:|---:|"
c7.first(top).each_with_index do |row, i|
  c = cpu_row[row["site"]]
  puts "| #{i + 1} | `#{row["site"]}` | #{row["apps"]} | #{row["mean_objects_per_op"]} | #{cpu_rank[row["site"]] || "-"} | " \
    "#{c ? Integer(Float(c["mean_ir_per_op"])) : "-"} | #{c ? format("%.2f", Float(c["pct_of_all_ir"])) : "-"} |"
end
both = cpu.first(top).map { _1["site"] } & c7.first(top).map { _1["site"] }
puts
puts "In both top #{top}: #{both.size}"
