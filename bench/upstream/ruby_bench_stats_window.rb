# How much of the default harness's whole-process JIT stats falls outside the
# measured window. Input: a default-harness run with WARMUP_ITRS=15
# MIN_BENCH_ITRS=25 MIN_BENCH_TIME=0, ZJIT_BENCH_STATS (or YJIT_BENCH_STATS)
# set to the counters to check, stdout saved as TAG.log and RESULT_JSON_PATH
# as TAG.json. The first 25 iterations stand for the default 15 warmup + 10
# measured; boot is the process total minus the sum of all iterations.
# Usage: ruby ruby_bench_stats_window.rb DIR TAG...
require "json"

dir = ARGV.shift
ARGV.each do |tag|
  log = File.readlines(File.join(dir, "#{tag}.log"))
  keys = log.find { |l| l.start_with?("itr:") }.split[2..]
  rows = log.grep(/\A\s*#\d+:/).map { |l| f = l.split; [f[1].to_i] + f[2..].map { |x| x.delete(",").to_i } }
  json = JSON.parse(File.read(File.join(dir, "#{tag}.json")))
  stats = json["zjit_stats"] || json["yjit_stats"]
  puts "== #{tag} (#{rows.size} iterations)"
  keys.each_with_index do |key, i|
    total = stats[key]
    next unless total.is_a?(Numeric)
    col = rows.map { |r| r[i + 1] }
    boot = total - col.sum
    whole = boot + col.first(25).sum
    window = col[15, 10].sum
    next if whole.zero?
    puts format("  %-28s window %14.1f/itr  whole/25 %14.1f/itr  outside window %5.1f%%  boot %5.1f%%",
      key, window / 10.0, whole / 25.0, (1 - window.fdiv(whole)) * 100, boot * 100.0 / whole)
  end
  times = rows.map(&:first)
  puts format("  ms: itr 1 %d, mean 6-15 %d, mean 16-25 %d, mean 26-40 %d",
    times[0], times[5, 10].sum / 10, times[15, 10].sum / 10, times[25, 15].sum / 15)
end
