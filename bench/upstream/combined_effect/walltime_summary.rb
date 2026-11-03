# frozen_string_literal: true

# Summarize walltime.sh output: ruby walltime_summary.rb OUT
# Per process: median ms of the timed iterations, mean GC runs, major GCs and
# allocated objects per timed iteration. Per round: with (mean of with-A and
# with-B) over without (mean of without-A and without-B), and the two A/A
# ratios (with-B / with-A, without-B / without-A). Reported: medians over
# rounds, the range, and a 95% t-interval of the mean log ratio.
require "json"

out = ARGV.fetch(0)
median = ->(a) { s = a.sort; s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0 }
mean = ->(a) { a.sum.to_f / a.size }
T95 = { 2 => 12.71, 3 => 4.30, 4 => 3.18, 5 => 2.78, 6 => 2.57, 7 => 2.45, 8 => 2.36, 9 => 2.31, 10 => 2.26, 11 => 2.23,
  12 => 2.20, 13 => 2.18, 14 => 2.16, 15 => 2.14, 16 => 2.13 }.freeze
ci = lambda do |ratios|
  logs = ratios.map { Math.log(_1) }
  m = mean.(logs)
  sd = Math.sqrt(logs.sum { (_1 - m)**2 } / (logs.size - 1))
  h = T95.fetch(logs.size, 2.0) * sd / Math.sqrt(logs.size)
  [Math.exp(m), Math.exp(m - h), Math.exp(m + h)]
end
pct = ->(r) { format("%+.1f%%", (r - 1) * 100).sub("-", "−") }

runs = Hash.new { |h, k| h[k] = {} }
Dir[File.join(out, "*.json")].each do |f|
  app, mode, variant, ab, round = File.basename(f, ".json").split("-")
  data = JSON.parse(File.read(f))
  timed = data["iterations"].drop(data["warmup"])
  runs[[app, mode]][["#{variant}-#{ab}", round]] = { ms: median.(timed.map { _1["ms"] }), gc: mean.(timed.map { _1["gc"] }),
    major: mean.(timed.map { _1["major"] }), objects: mean.(timed.map { _1["objects"] }), rails: data["rails"] }
end

puts "| App | Mode | Rounds | without ms | with ms | with / without: median (range) | mean [95% CI] | A/A with | A/A without | GC/iter without → with | major/iter | objects/iter without → with |"
puts "| --- | --- | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- | --- |"
runs.sort.each do |(app, mode), r|
  rounds = r.keys.map(&:last).uniq.select { |rd| %w[with-A with-B without-A without-B].all? { r.key?([_1, rd]) } }
  next if rounds.size < 2
  get = ->(v, rd, k) { r.fetch([v, rd]).fetch(k) }
  pair = ->(side, rd, k) { (get.("#{side}-A", rd, k) + get.("#{side}-B", rd, k)) / 2.0 }
  ratios = rounds.map { pair.("with", _1, :ms) / pair.("without", _1, :ms) }
  aa_w = rounds.map { get.("with-B", _1, :ms) / get.("with-A", _1, :ms) }
  aa_o = rounds.map { get.("without-B", _1, :ms) / get.("without-A", _1, :ms) }
  m, lo, hi = ci.(ratios)
  side = ->(s, k) { mean.(rounds.map { pair.(s, _1, k) }) }
  fmt_aa = ->(a) { c = ci.(a); "#{pct.(median.(a))} (#{pct.(a.min)} … #{pct.(a.max)}); [#{pct.(c[1])}, #{pct.(c[2])}]" }
  puts "| #{app} | #{mode == "yjit" ? "YJIT" : "interpreter"} | #{rounds.size} | #{median.(rounds.map { pair.("without", _1, :ms) }).round(1)} | " \
    "#{median.(rounds.map { pair.("with", _1, :ms) }).round(1)} | #{pct.(median.(ratios))} (#{pct.(ratios.min)} … #{pct.(ratios.max)}) | " \
    "#{pct.(m)} [#{pct.(lo)}, #{pct.(hi)}] | #{fmt_aa.(aa_w)} | #{fmt_aa.(aa_o)} | " \
    "#{side.("without", :gc).round(2)} → #{side.("with", :gc).round(2)} | #{side.("without", :major).round(2)} → #{side.("with", :major).round(2)} | " \
    "#{side.("without", :objects).round} → #{side.("with", :objects).round} (#{pct.(side.("with", :objects) / side.("without", :objects))}) |"
end
