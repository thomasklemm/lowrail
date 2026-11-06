# permeans.rb OUTPUT.json: per-process mean bench time (ms) per executable and benchmark.
require "json"
j = JSON.parse(File.read(ARGV[0]))
j["raw_data"].each do |exe, bs|
  bs.each do |b, r|
    per = r["bench_itrs_per_run"]; xs = r["bench"]
    means = per ? xs.each_slice(xs.size / per.size).map { _1.sum / _1.size * 1000 } : [xs.sum / xs.size * 1000]
    m = means.sum / means.size
    sd = means.size > 1 ? Math.sqrt(means.sum { (_1 - m)**2 } / (means.size - 1)) : 0
    printf("%-11s %-6s n=%d mean %7.1f  sd %.1f%%  procs %s\n", b, exe, means.size, m, 100 * sd / m, means.map { _1.round }.inspect)
  end
end
