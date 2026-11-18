# A/A-filtered ZJIT stats diff for docs/upstream/zjit-stats-2026-11-18.md (evening pass).
#   ruby diff.rb [--min N] [--all] BASE.json NEW.json AA.json
# Prints, in diff format, every per-iteration counter that moved from BASE to NEW by at least
# --min (default 10) and by more than 3x its NEW/AA difference, which is the A/A noise of a second
# build of NEW. Timing counters (*_time_ns) and per-ISEQ call counts are left out unless --all.
require "json"
min = ARGV.include?("--min") ? Float(ARGV[ARGV.index("--min") + 1]) : 10.0
all = ARGV.delete("--all")
base, new, aa = ARGV.grep(/\.json\z/).map { |f| JSON.parse(File.read(f)).fetch("per_itr") }

def fmt(v) = v >= 100 ? v.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse : v.round(1).to_s

keys = (base.keys | new.keys).reject { |k| !all && (k.end_with?("_time_ns") || k.start_with?("iseq_calls_count_")) }
rows = keys.filter_map do |k|
  b, n, a = base.fetch(k, 0.0), new.fetch(k, 0.0), aa.fetch(k, 0.0)
  d, noise = n - b, (n - a).abs
  [k, b, n, a, d, noise] if d.abs >= min && d.abs > 3 * noise
end
rows.sort_by { |_, b, _, _, d, _| -d.abs }.each do |k, b, n, a, d, noise|
  puts "-#{k.ljust(52)}#{fmt(b).rjust(12)}"
  puts "+#{k.ljust(52)}#{fmt(n).rjust(12)}   (#{d.positive? ? "+" : "-"}#{fmt(d.abs)}#{", #{(d / b * 100).round(1)}%" if b != 0}, A/A #{fmt(noise)})"
end
