# frozen_string_literal: true

# ruby an.rb OUT.jsonl [BASE=main]
# Per process: median of its windows (ns/call). Per round: log(arm / base) for the
# same (mode, cols, case). Estimate: mean over rounds, 95% CI by a seeded bootstrap
# over rounds (10,000 resamples). An arm is "distinguishable" when its CI excludes 0
# and is outside the A/A arm's (main2) CI.
require "json"

file, base = ARGV
base ||= "main"
rows = File.readlines(file).map { JSON.parse(_1) }
med = ->(a) { s = a.sort; n = s.size; n.odd? ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2.0 }
by = Hash.new { |h, k| h[k] = {} }
jit = Hash.new(0)
rows.each do |r|
  r[ENV.fetch("FIELD", "ns")].each { |c, w| by[[r["mode"], r["cols"], c]][[r["arm"], r["round"]]] = med.(w) }
  %w[yjit zjit].each do |k|
    next unless (a = r["jit_after"][k]) && (b = r["jit_before"][k])
    d = (a["compiled_iseq_count"] || 0) - (b["compiled_iseq_count"] || 0)
    d += (a["invalidation_count"] || 0) - (b["invalidation_count"] || 0)
    d += (a["compiled_block_count"] || 0) - (b["compiled_block_count"] || 0)
    jit[[r["mode"], r["cols"], r["arm"]]] += 1 if d != 0
  end
end
rng = Random.new(42)
boot = lambda do |xs|
  means = Array.new(10_000) { xs.sum { xs[rng.rand(xs.size)] } / xs.size }.sort
  [means[250], means[9_749]]
end
pct = ->(x) { format("%+.2f%%", (Math.exp(x) - 1) * 100) }
arms = rows.map { _1["arm"] }.uniq - [base]
puts "# #{file}: per-process median of windows, mean of per-round log ratios vs #{base}, 95% bootstrap CI over rounds"
puts "| mode | cols | case | #{base} ns/call | " + arms.map { "#{_1} vs #{base} [95% CI]" }.join(" | ") + " | rounds |"
puts "|---|---:|---|---:|" + arms.map { "---:" }.join("|") + "|---:|"
by.sort.each do |(mode, cols, c), v|
  rounds = v.keys.map(&:last).uniq.sort
  cells = arms.map do |arm|
    xs = rounds.filter_map { |r| (a = v[[arm, r]]) && (b = v[[base, r]]) && Math.log(a / b) }
    next "n/a" if xs.empty?
    lo, hi = boot.(xs)
    "#{pct.(xs.sum / xs.size)} [#{pct.(lo)}, #{pct.(hi)}]"
  end
  b = med.(rounds.filter_map { v[[base, _1]] })
  puts "| #{mode} | #{cols} | #{c} | #{b.round} | #{cells.join(' | ')} | #{rounds.size} |"
end
bad = jit.select { |_, n| n > 0 }
puts
puts(bad.empty? ? "JIT-flat: every JIT process compiled and invalidated nothing during its windows." :
  "Not JIT-flat (processes with compiles/invalidations during windows): " + bad.map { |(m, c, a), n| "#{m}/#{c}/#{a}: #{n}" }.join(", "))
