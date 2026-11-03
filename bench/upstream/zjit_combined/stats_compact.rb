# frozen_string_literal: true

# Compact per-app ZJIT counter table for docs/upstream/combined-effect.md:
# dynamic sends, send/ivar fallbacks and side exits (without the out-of-memory
# compile-error exits, which follow --zjit-mem-size), per operation.
#   ruby stats_compact.rb OUT WITH WITH2 WITHOUT WITHOUT2
require "json"
out, *labels = ARGV
FALLBACK = /\A(send_fallback_|send_direct_fallback_|getivar_fallback_|setivar_fallback_)/
cols = {
  "Dynamic sends" => ->(h) { h["dynamic_send_count"].to_f },
  "Fallbacks" => ->(h) { h.sum { |k, v| k.match?(FALLBACK) ? v : 0 } },
  "Side exits" => ->(h) { h["side_exit_count"].to_f - h["exit_compile_error"].to_f },
}
num = ->(v) { format(v.abs >= 100 ? "%.0f" : "%.1f", v).sub("-", "−") }
pct = ->(d, b) { format("%+.1f%%", 100.0 * d / b).sub("-", "−") }
puts "| App | #{cols.keys.map { "#{_1} without → with (Δ; A/A)" }.join(" | ")} |"
puts "| --- |#{" ---: |" * cols.size}"
tot = Hash.new { |h, k| h[k] = [0.0, 0.0] }
Dir["#{out}/#{labels[0]}/*-zjit.json"].map { File.basename(_1, "-zjit.json") }.sort.each do |app|
  w1, w2, o1, o2 = labels.map { JSON.parse(File.read("#{out}/#{_1}/#{app}-zjit.json"))["per_op"] }
  cells = cols.map do |name, f|
    w, o = (f.(w1) + f.(w2)) / 2, (f.(o1) + f.(o2)) / 2
    aa = [f.(w2) - f.(w1), f.(o2) - f.(o1)].max_by(&:abs)
    "#{num.(o)} → #{num.(w)} (#{pct.(w - o, o)}; ±#{pct.(aa.abs, o).delete("+")})"
  end
  puts "| #{app} | #{cells.join(" | ")} |"
end
