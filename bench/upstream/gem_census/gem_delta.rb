# frozen_string_literal: true

# Census delta of one gem's own lines, for docs/upstream/gem-census.md:
#   ruby gem_delta.rb OUT GEM BASE AA LABEL MODE [APPS]
# Per app: mean objects per operation (over the app's workloads) allocated in
# GEM's lines in BASE, the change in LABEL, and the change in the A/A twin AA.
# Also the change in all allocations (all sites), which carries the apps' noise.
# Lines are keyed as in `rank --gem all`, so a git checkout and a released gem
# of the same code compare equal.
require "json"
require_relative "../census/rank"

out, gem, base, aa, label, mode, apps = ARGV
apps = apps&.split(",")

def load(out, label, mode)
  CensusRank.load_runs(File.join(out, label), mode).to_h { [_1["app"], _1["workloads"]] }
end

def sums(workloads, gem)
  workloads.to_h do |w|
    own = w["sites"].sum { |s| (k, = CensusRank::ALL_GEMS.(s["file"], s["line"])) && k.start_with?("#{gem}/") ? s["objects_per_op"] : 0.0 }
    [w["workload"], [own, w["sites"].sum { _1["objects_per_op"] }]]
  end
end

b, a, l = [base, aa, label].map { load(out, _1, mode) }
rows = (apps || b.keys.sort).filter_map do |app|
  next unless b[app] && a[app] && l[app]
  sb, sa, sl = [b, a, l].map { sums(_1[app], gem) }
  names = sb.keys & sa.keys & sl.keys
  mean = ->(s, i) { names.sum { s[_1][i] } / names.size }
  [app, names.size, mean.(sb, 0), mean.(sl, 0) - mean.(sb, 0), mean.(sa, 0) - mean.(sb, 0),
    mean.(sl, 1) - mean.(sb, 1), mean.(sa, 1) - mean.(sb, 1), mean.(sb, 1)]
end
f = ->(v) { format("%+.1f", v).sub("-", "−") }
puts "| App | Workloads | #{gem} objects/op | #{label} | A/A | All objects/op | #{label} all | A/A all |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
rows.each do |app, n, own, d, dz, t, tz, all|
  next if own < 0.05
  puts "| #{app} | #{n} | #{format("%.1f", own)} | #{f.(d)} | #{f.(dz)} | #{format("%.0f", all)} | #{f.(t)} | #{f.(tz)} |"
end
n = rows.sum { _2 }
w = ->(i) { rows.sum { |row| row[1] * row[i] } / n }
puts "| **All (#{rows.size} configurations)** | #{n} | #{format("%.1f", w.(2))} | #{f.(w.(3))} | #{f.(w.(4))} | #{format("%.0f", w.(7))} | #{f.(w.(5))} | #{f.(w.(6))} |"
reached = rows.select { _4 <= -0.5 }
puts "reached (own delta <= -0.5): #{reached.size} configurations, #{reached.map { _1[0].sub(/-(mysql|nops)\z/, "") }.uniq.size} apps; " \
  "share of all allocations removed: #{format("%.3f%%", -100 * w.(3) / w.(7))}"
