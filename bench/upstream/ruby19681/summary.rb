# Summarizes rounds.sh output: per benchmark and executable, the median over rounds of compile_time_ns,
# compile_lir_time_ns and the mean non-warmup iteration time, each as a change against master, with the
# range over rounds and the per-round paired change (same round, same run_benchmarks invocation).
#   ruby summary.rb OUT_DIR
require "json"

def median(xs) = (s = xs.sort; n = s.size; n.odd? ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2.0)
def pct(a, b) = format("%+.1f%%", (a / b.to_f - 1) * 100)

dir = ARGV.fetch(0)
%w[railsbench lobsters shipit].each do |bench|
  files = Dir["#{dir}/#{bench}-r*.json"].sort_by { _1[/r(\d+)\.json/, 1].to_i }
  next if files.empty?
  rows = files.map do |f|
    raw = JSON.parse(File.read(f)).fetch("raw_data")
    raw.to_h do |exe, benches|
      b = benches.fetch(bench)
      z = b.fetch("zjit_stats")
      [exe, { ct: z.fetch("compile_time_ns") / 1e6, lir: z.fetch("compile_lir_time_ns") / 1e6,
              t: b.fetch("bench").sum / b.fetch("bench").size * 1000.0,
              iseqs: z["compiled_iseq_count"], bytes: z["code_region_bytes"],
              oom: z.fetch("compile_error_out_of_memory", 0) }]
    end
  end
  puts "#{bench}: #{rows.size} rounds"
  %i[ct lir t].each do |k|
    base = median(rows.map { _1["master"][k] })
    line = format("  %-4s master %9.1f", k, base)
    %w[aa head].each do |exe|
      vals = rows.map { _1[exe][k] }
      paired = rows.map { (_1[exe][k] / _1["master"][k] - 1) * 100 }
      line << format("  %s %9.1f (%s; paired median %+.1f%%, range %+.1f…%+.1f%%)", exe, median(vals),
                     pct(median(vals), base), median(paired), paired.min, paired.max)
    end
    puts line
  end
  # Run order inside a round, as rounds.sh rotates it (round number mod 3).
  orders = { 1 => %w[head master aa], 2 => %w[aa head master], 0 => %w[master aa head] }
  rounds = files.map { _1[/r(\d+)\.json/, 1].to_i }
  %w[master aa head].each do |exe|
    by_pos = (0..2).map do |pos|
      vals = rows.zip(rounds).select { |_, r| orders[r % 3][pos] == exe }.map { |row, _| row[exe][:ct] }
      vals.empty? ? "-" : format("%.0f (n=%d)", vals.sum / vals.size, vals.size)
    end
    puts format("  ct by run position, %-6s 1st %s, 2nd %s, 3rd %s", exe, *by_pos)
  end
  mr = rows.map { _1["master"][:ct] }
  puts format("  master compile_time range %.0f…%.0f ms; iseqs master %s head %s; code bytes master %s head %s",
              mr.min, mr.max, rows.map { _1["master"][:iseqs] }.minmax.join("…"),
              rows.map { _1["head"][:iseqs] }.minmax.join("…"),
              rows.map { _1["master"][:bytes] }.minmax.join("…"), rows.map { _1["head"][:bytes] }.minmax.join("…"))
end
