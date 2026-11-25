# Prints ruby-bench's own results table for all rounds of rounds.sh pooled: per executable, the
# non-warmup iteration times of every round together, and per ZJIT stat the median over rounds.
#   ruby pooled_table.rb RUBY_BENCH_DIR OUT_DIR
require "json"
rb, dir = ARGV
require File.join(rb, "lib/results_table_builder")
require File.join(rb, "lib/table_formatter")

def median(xs) = (s = xs.sort; n = s.size; n.odd? ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2.0)

exes = %w[master aa head]
stats = %w[compile_time_ns compile_lir_time_ns]
data = exes.to_h { [_1, {}] }
%w[railsbench lobsters shipit].each do |bench|
  runs = Dir["#{dir}/#{bench}-r*.json"].map { JSON.parse(File.read(_1)).fetch("raw_data") }
  exes.each do |exe|
    rs = runs.map { _1.fetch(exe).fetch(bench) }
    data[exe][bench] = {
      "warmup" => rs.flat_map { _1["warmup"] }, "bench" => rs.flat_map { _1["bench"] },
      "rss" => median(rs.map { _1["rss"] }),
      "zjit_stats" => stats.to_h { |s| [s, median(rs.map { _1["zjit_stats"][s] }).round] },
    }
  end
end
builder = ResultsTableBuilder.new(executable_names: exes, bench_data: data, zjit_stats: stats, include_pvalue: true)
table, format = builder.build
puts TableFormatter.new(table, format, {}).to_s
