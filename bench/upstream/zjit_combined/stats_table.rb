# frozen_string_literal: true

# ZJIT counter comparison for docs/upstream/combined-effect.md: census --stats
# runs (harness.rb stats, per operation) on Rails main (WITH, WITH2) and the
# reverted tree (WITHOUT, WITHOUT2).
#   ruby stats_table.rb OUT WITH WITH2 WITHOUT WITHOUT2
# Prints per app the headline counters (pair means, PRs' delta, both A/A
# deltas), then every fallback, side-exit and unspecialized-send counter that the
# PRs raise: delta > 0, above 2x the larger A/A delta, > 5% of the reverted value
# and >= 0.05 per operation.
require "json"

out, *labels = ARGV
abort "usage: stats_table.rb OUT WITH WITH2 WITHOUT WITHOUT2" unless labels.size == 4
FAMILIES = /\A(exit_|send_fallback_|send_direct_fallback_|unspecialized_|getivar_fallback_|setivar_fallback_|complex_arg_pass_|inline_reject_|invokeblock_handler_polymorphic|throw_count)/
HEAD = %w[send_count dynamic_send_count side_exit_count fallbacks exits compiled_iseq_count].freeze

apps = Dir["#{out}/#{labels[0]}/*-zjit.json"].map { File.basename(_1, "-zjit.json") }.sort
data = apps.to_h do |app|
  runs = labels.map { JSON.parse(File.read("#{out}/#{_1}/#{app}-zjit.json"))["per_op"] }
  runs.each do |h|
    h["fallbacks"] = h.sum { |k, v| k.match?(/\A(send_fallback_|send_direct_fallback_|getivar_fallback_|setivar_fallback_)/) ? v : 0 }
    h["exits"] = h.sum { |k, v| k.start_with?("exit_") ? v : 0 }
  end
  [app, runs]
end

fmt = ->(v) { format(v.abs >= 100 ? "%.0f" : "%.2f", v).sub("-", "−") }
sgn = ->(v) { (v >= 0 ? "+" : "") + fmt.(v) }
puts "| App | #{HEAD.join(" | ")} |"
puts "| --- |#{" ---: |" * HEAD.size}"
data.each do |app, (w1, w2, o1, o2)|
  cells = HEAD.map do |k|
    w = (w1[k].to_f + w2[k].to_f) / 2
    o = (o1[k].to_f + o2[k].to_f) / 2
    "#{fmt.(o)} → #{fmt.(w)} (#{sgn.(w - o)}; A/A #{sgn.(w2[k].to_f - w1[k].to_f)}, #{sgn.(o2[k].to_f - o1[k].to_f)})"
  end
  puts "| #{app} | #{cells.join(" | ")} |"
end

puts
puts "Counters raised by the PRs (per operation):"
raised = Hash.new { |h, k| h[k] = [] }
data.each do |app, (w1, w2, o1, o2)|
  (w1.keys | w2.keys | o1.keys | o2.keys).grep(FAMILIES).each do |k|
    a, b, c, d = [w1, w2, o1, o2].map { _1[k].to_f }
    w, o = (a + b) / 2, (c + d) / 2
    delta = w - o
    aa = [(b - a).abs, (d - c).abs].max
    next unless delta >= 0.05 && delta > 2 * aa && (o.zero? || delta / o > 0.05)
    raised[k] << app
    puts format("  %-20s %-60s %8.3f -> %8.3f  (A/A %.3f, %.3f)", app, k, o, w, b - a, d - c)
  end
end
puts "  (none)" if raised.empty?
puts
puts "By counter (apps):"
raised.sort_by { -_2.size }.each { |k, a| puts "  #{k}: #{a.size} (#{a.join(", ")})" }
