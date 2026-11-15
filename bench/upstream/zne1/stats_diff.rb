# frozen_string_literal: true

# Per-iteration ZJIT counter diff between two stats_harness.rb outputs, in diff format.
#   ruby stats_diff.rb BEFORE.json AFTER.json [NOISE_A.json NOISE_B.json] [--min N] [--pct P]
# With an A/A pair, a counter is printed only when its change is at least 3 times the A/A change;
# without, when it moves by at least --pct percent (default 2) and --min per iteration (default 100).
require "json"

args = ARGV.reject { _1.start_with?("--") }
opt = ->(name, default) { (i = ARGV.index(name)) ? Float(ARGV[i + 1]) : default }
args -= [ARGV[ARGV.index("--min") + 1]] if ARGV.include?("--min")
args -= [ARGV[ARGV.index("--pct") + 1]] if ARGV.include?("--pct")
min = opt.("--min", 100)
pct = opt.("--pct", 2)
load_stats = ->(path) { d = JSON.parse(File.read(path)); d["stats"].transform_values { _1.fdiv(d["itrs"]) } }
before, after, noise_a, noise_b = args.map(&load_stats)
skip = /time_ns\z|_bytes\z|\Acompile_|gc_|\Aiseq_calls_count_/
fmt = ->(v) { v.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }

(before.keys | after.keys).sort.each do |key|
  next if key.match?(skip)
  a = before.fetch(key, 0.0)
  b = after.fetch(key, 0.0)
  delta = b - a
  next if delta.abs < min || delta.abs < [a, b].max * pct / 100
  next if noise_a && delta.abs < 3 * (noise_b.fetch(key, 0.0) - noise_a.fetch(key, 0.0)).abs
  puts "-#{key}: #{fmt.(a)}"
  puts "+#{key}: #{fmt.(b)} (#{"%+d" % delta.round})"
end
