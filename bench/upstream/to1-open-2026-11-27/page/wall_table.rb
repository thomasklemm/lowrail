# frozen_string_literal: true

# Page wall table for TO1 (README, Page level): bench/upstream/zjit_gap_bet/wall_table.rb's method on rounds of
# Rails main twice (a, b) and the TO1 head once (h), each a fresh `script/census run --wall --only` process.
#   ruby wall_table.rb DIR   (DIR/APP-MODE/rNN-{a,b,h}/APP-MODE.json)
# Per process: the mean of its JIT-flat timed windows over the requests in a window. Per round: change =
# h / mean(a, b), A/A = a / b. Across rounds: the geometric mean with a 95% bootstrap interval over rounds
# (10,000 resamples, seed 42). A change counts with at least 10 rounds, an A/A interval that contains 0 and a
# change interval that doesn't.
require "json"

def process(path)
  j = JSON.parse(File.read(path))
  flat = j["windows"].select { _1["flat"] }
  { ms: flat.empty? ? nil : flat.sum { _1["ms"] } / flat.size / j["ops"], flat: flat.size, timed: j["windows"].size,
    gc: j["windows"].sum { _1["gc_ms"] } / j["windows"].sum { _1["ms"] }, ruby: j["ruby"], rails: j["rails"] }
end

def geomean(xs) = Math.exp(xs.sum { Math.log(_1) } / xs.size)

def interval(xs)
  rng = Random.new(42)
  means = Array.new(10_000) { geomean(Array.new(xs.size) { xs[rng.rand(xs.size)] }) }.sort
  [geomean(xs), means[250], means[9749]]
end

def pct(x) = format("%+.1f%%", (x - 1) * 100)
def cell((g, lo, hi)) = "#{pct(g)} [#{pct(lo)}, #{pct(hi)}]"

dir = ARGV.fetch(0)
puts "| page | mode | rounds | main ms | TO1 ms | change [95%] | A/A [95%] | flat windows main, TO1 | GC share | verdict |"
puts "| --- | --- | ---: | ---: | ---: | --- | --- | --- | ---: | --- |"
Dir.children(dir).sort.each do |cohort|
  next unless File.directory?(File.join(dir, cohort)) && cohort.match?(/-(yjit|zjit)\z/)
  app, mode = cohort.split("-")
  procs = Dir.glob(File.join(dir, cohort, "r*-?", "*.json")).reject { _1.end_with?("meta.json") }
    .to_h { [File.basename(File.dirname(_1)), process(_1)] }
  rounds = procs.keys.map { _1[/\Ar\d+/] }.uniq.sort.filter_map do |r|
    a, b, h = %w[a b h].map { procs["#{r}-#{_1}"] }
    next unless [a, b, h].all? { _1 && _1[:ms] }
    { base: (a[:ms] + b[:ms]) / 2, h: h[:ms], change: h[:ms] / ((a[:ms] + b[:ms]) / 2), aa: a[:ms] / b[:ms] }
  end
  next if rounds.empty?
  change, aa = interval(rounds.map { _1[:change] }), interval(rounds.map { _1[:aa] })
  verdict = if rounds.size < 10 then "under 10 rounds, no claim"
  elsif !(aa[1] <= 1 && aa[2] >= 1) then "A/A excludes 0, no claim"
  elsif change[1] <= 1 && change[2] >= 1 then "inside noise"
  else "counts"
  end
  flat = ->(sides) { sel = procs.select { |k, _| sides.include?(k[-1]) }.values; "#{sel.sum { _1[:flat] }}/#{sel.sum { _1[:timed] }}" }
  gc = procs.values.sum { _1[:gc] } / procs.size
  puts "| #{app} | #{mode} | #{rounds.size} | #{format("%.3f", geomean(rounds.map { _1[:base] }))} | " \
    "#{format("%.3f", geomean(rounds.map { _1[:h] }))} | #{cell(change)} | #{cell(aa)} | #{flat.(%w[a b])}, #{flat.(%w[h])} | " \
    "#{format("%.1f%%", gc * 100)} | #{verdict} |"
end
puts
puts "Rubies: " + Dir.glob(File.join(dir, "*", "r*-?", "*.json")).reject { _1.end_with?("meta.json") }
  .map { JSON.parse(File.read(_1))["ruby"] }.uniq.join("; ")
