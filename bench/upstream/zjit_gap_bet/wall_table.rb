# frozen_string_literal: true

# Tables for bench/upstream/zjit_gap_bet/HANDOFF.md from wall_queue.sh's output.
#   ruby wall_table.rb OUT [--json FILE]
# Per process: the mean wall time of its JIT-flat timed iterations (ruby-bench) or windows (census apps); a timed
# iteration in which the JIT compiled or invalidated something is rejected and counted. Per round: ZJIT/YJIT is the
# mean of the two ZJIT processes over the mean of the two YJIT processes; the A/A ratios are twin a over twin b.
# Across rounds: the geometric mean with a 95% bootstrap interval over rounds (10,000 resamples, fixed seed).
require "json"

out = ARGV.fetch(0)
json_out = ARGV.include?("--json") ? ARGV[ARGV.index("--json") + 1] : nil

def process(path)
  j = JSON.parse(File.read(path))
  rows = j["itrs"] || j["windows"]
  flat = rows.select { _1["flat"] }
  per = j["ops"] ? j["ops"].to_f : 1.0 # census: ms per operation
  { mean: flat.empty? ? nil : flat.sum { _1["ms"] } / flat.size / per, all: rows.sum { _1["ms"] } / rows.size / per,
    gc: rows.sum { _1["gc_ms"] } / rows.sum { _1["ms"] }, timed: rows.size, rejected: rows.size - flat.size,
    gate: j["gate"], ruby: j["ruby"] }
end

def geomean(xs) = Math.exp(xs.sum { Math.log(_1) } / xs.size)

def interval(xs)
  rng = Random.new(42)
  means = Array.new(10_000) { geomean(Array.new(xs.size) { xs[rng.rand(xs.size)] }) }.sort
  [geomean(xs), means[250], means[9749], xs.min, xs.max]
end

def pct(x) = format("%+.1f%%", (x - 1) * 100)
def cell(xs) = xs.empty? ? "–" : (g, lo, hi, = interval(xs); "#{pct(g)} [#{pct(lo)}, #{pct(hi)}]")

result = {}
Dir.children(out).sort.each do |target|
  dir = File.join(out, target)
  next unless File.directory?(dir)
  rounds = Dir.glob(File.join(dir, "r*-*.json")).group_by { File.basename(_1)[/\Ar\d+/] }
  rows = rounds.sort.filter_map do |round, files|
    p = files.to_h { [File.basename(_1, ".json").sub(/\Ar\d+-/, ""), process(_1)] }
    next unless %w[yjit-a yjit-b zjit-a zjit-b].all? { p[_1] && p[_1][:mean] }
    y = (p["yjit-a"][:mean] + p["yjit-b"][:mean]) / 2
    z = (p["zjit-a"][:mean] + p["zjit-b"][:mean]) / 2
    ya = (p["yjit-a"][:all] + p["yjit-b"][:all]) / 2
    za = (p["zjit-a"][:all] + p["zjit-b"][:all]) / 2
    { round:, p:, y:, z:, ratio: z / y, ratio_all: za / ya, aa_y: p["yjit-a"][:mean] / p["yjit-b"][:mean],
      aa_z: p["zjit-a"][:mean] / p["zjit-b"][:mean], h: p["hzjit"] && p["hzjit"][:mean] && p["hzjit"][:mean] / y }
  end
  next if rows.empty?
  procs = rows.flat_map { |r| r[:p].map { |name, v| [name, v] } }
  count = ->(mode) { sel = procs.select { _1.start_with?(mode) }.map(&:last); [sel.count { _1[:gate] == "pass" }, sel.size, sel.sum { _1[:rejected] }, sel.sum { _1[:timed] }] }
  result[target] = { rounds: rows.size, yjit_ms: geomean(rows.map { _1[:y] }), zjit_ms: geomean(rows.map { _1[:z] }),
    ratio: interval(rows.map { _1[:ratio] }), ratio_all: interval(rows.map { _1[:ratio_all] }),
    aa_yjit: interval(rows.map { _1[:aa_y] }), aa_zjit: interval(rows.map { _1[:aa_z] }),
    headline: rows.all? { _1[:h] } ? interval(rows.map { _1[:h] }) : nil,
    gate: { yjit: count.("yjit"), zjit: count.("zjit"), hzjit: count.("hzjit") },
    gc_share: { yjit: procs.select { _1[0].start_with?("yjit") }.sum { _1[1][:gc] } / (2 * rows.size), zjit: procs.select { _1[0].start_with?("zjit") }.sum { _1[1][:gc] } / (2 * rows.size) },
    per_round: rows.map { |r| { round: r[:round], yjit: r[:p].values_at("yjit-a", "yjit-b").map { _1[:mean].round(3) }, zjit: r[:p].values_at("zjit-a", "zjit-b").map { _1[:mean].round(3) }, hzjit: r[:p]["hzjit"]&.dig(:mean)&.round(3), ratio: r[:ratio].round(4) } },
    rubies: procs.map { _1[1][:ruby] }.uniq }
end

puts "| benchmark | rounds | YJIT ms | ZJIT ms | ZJIT/YJIT [95% CI] | per-round range | A/A YJIT | A/A ZJIT | headline ZJIT / YJIT | rejected timed iterations (YJIT, ZJIT, headline) |"
puts "| --- | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- |"
result.each do |target, r|
  g = r[:gate]
  puts "| #{target} | #{r[:rounds]} | #{format("%.2f", r[:yjit_ms])} | #{format("%.2f", r[:zjit_ms])} | **#{pct(r[:ratio][0])}** [#{pct(r[:ratio][1])}, #{pct(r[:ratio][2])}] | " \
    "#{pct(r[:ratio][3])} to #{pct(r[:ratio][4])} | #{pct(r[:aa_yjit][0])} [#{pct(r[:aa_yjit][1])}, #{pct(r[:aa_yjit][2])}] | " \
    "#{pct(r[:aa_zjit][0])} [#{pct(r[:aa_zjit][1])}, #{pct(r[:aa_zjit][2])}] | " \
    "#{r[:headline] ? "#{pct(r[:headline][0])} [#{pct(r[:headline][1])}, #{pct(r[:headline][2])}]" : "–"} | " \
    "#{%i[yjit zjit hzjit].map { "#{g[_1][2]}/#{g[_1][3]}" }.join(", ")} |"
end
puts
puts "All timed iterations, rejected ones included (ZJIT/YJIT): " + result.map { |t, r| "#{t} #{pct(r[:ratio_all][0])}" }.join(", ")
puts "Processes whose every timed iteration was flat (YJIT, ZJIT, headline): " + result.map { |t, r| "#{t} #{%i[yjit zjit hzjit].map { "#{r[:gate][_1][0]}/#{r[:gate][_1][1]}" }.join(", ")}" }.join("; ")
File.write(json_out, JSON.pretty_generate(result) + "\n") if json_out
