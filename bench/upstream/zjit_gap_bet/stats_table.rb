# frozen_string_literal: true

# Counter tables for bench/upstream/zjit_gap_bet/HANDOFF.md from stats_queue.sh's JSONs.
#   ruby stats_table.rb DIR MASTER HEADLINE [--min N] [--cfuncs N]
# Per iteration, railsbench / lobsters / shipit: totals, then every fallback, exit and compile-error reason with at
# least N (default 2000) events per iteration on one build in one benchmark, master next to the headline branch.
require "json"

dir, master, headline = ARGV.first(3)
min = ARGV.include?("--min") ? Integer(ARGV[ARGV.index("--min") + 1]) : 2000
cfuncs = ARGV.include?("--cfuncs") ? Integer(ARGV[ARGV.index("--cfuncs") + 1]) : 12
BENCHES = %w[railsbench lobsters shipit].freeze
load = ->(bench, build, kind) { f = File.join(dir, "#{bench}-#{build}-#{kind}.json"); File.exist?(f) ? JSON.parse(File.read(f)) : nil }
data = BENCHES.to_h { |b| [b, { m: load.(b, master, "zjit"), h: load.(b, headline, "zjit"), y: load.(b, master, "yjit") }] }
fmt = ->(v) { v.nil? ? "–" : v >= 10_000 ? "#{(v / 1000.0).round}k" : v >= 1000 ? "#{(v / 1000.0).round(1)}k" : v.round.to_s }
row = ->(label, key, which) { "| #{label} | " + BENCHES.map { |b| fmt.(data[b][which]&.dig("per_itr", key) || (data[b][which] ? 0 : nil)) }.join(" / ") + " |" }

BENCHES.each do |b|
  %i[m h].each do |w|
    j = data[b][w] or next
    oom = [j.dig("before_reset", "compile_error_out_of_memory"), j.dig("window_end", "compile_error_out_of_memory")]
    warn "#{b} #{w}: compile_error_out_of_memory #{oom.inspect}, code region #{j.dig("window_end", "code_region_bytes").to_i / 1_048_576} MiB, #{j["ruby"]}"
  end
end

puts "| per iteration (railsbench / lobsters / shipit) | master ZJIT | headline ZJIT | master YJIT |"
puts "| --- | ---: | ---: | ---: |"
[["sends", "send_count", nil], ["dynamic sends", "dynamic_send_count", "num_send_dynamic"], ["side exits", "side_exit_count", "side_exit_count"],
 ["generic ivar reads", "dynamic_getivar_count", nil], ["generic ivar writes", "dynamic_setivar_count", nil], ["throws", "throw_count", nil]].each do |label, z, y|
  cells = %i[m h].map { |w| BENCHES.map { |b| fmt.(data[b][w]&.dig("per_itr", z) || (data[b][w] ? 0 : nil)) }.join(" / ") }
  ycell = y ? BENCHES.map { |b| fmt.(data[b][:y]&.dig("per_itr", y)) }.join(" / ") : "–"
  puts "| #{label} | #{cells[0]} | #{cells[1]} | #{ycell} |"
end

families = /\A(send_fallback_|getivar_fallback_|setivar_fallback_|exit_|compile_error_|complex_arg_pass_|unspecialized_send_|unspecialized_super_|caller_splat_|invokeblock_)/
keys = BENCHES.flat_map { |b| %i[m h].flat_map { |w| (data[b][w]&.fetch("per_itr") || {}).select { |k, v| k.match?(families) && v >= min }.keys } }.uniq
keys = keys.sort_by { |k| -BENCHES.sum { |b| data[b][:m]&.dig("per_itr", k).to_f } }
puts
puts "| reason (per iteration, railsbench / lobsters / shipit) | master ZJIT | headline ZJIT |"
puts "| --- | ---: | ---: |"
keys.each do |k|
  cells = %i[m h].map { |w| BENCHES.map { |b| fmt.(data[b][w]&.dig("per_itr", k) || (data[b][w] ? 0 : nil)) }.join(" / ") }
  puts "| `#{k}` | #{cells[0]} | #{cells[1]} |"
end

nk = BENCHES.flat_map { |b| (data[b][:h] || data[b][:m])&.fetch("per_itr")&.select { |k, _| k.start_with?("not_inlined_cfuncs_") }&.max_by(cfuncs) { _2 }&.map(&:first) || [] }.uniq
nk = nk.sort_by { |k| -BENCHES.sum { |b| (data[b][:h] || data[b][:m])&.dig("per_itr", k).to_f } }.first(cfuncs * 2)
puts
puts "| C method called with a frame (per iteration) | master ZJIT | headline ZJIT |"
puts "| --- | ---: | ---: |"
nk.each do |k|
  cells = %i[m h].map { |w| BENCHES.map { |b| fmt.(data[b][w]&.dig("per_itr", k) || (data[b][w] ? 0 : nil)) }.join(" / ") }
  puts "| `#{k.delete_prefix("not_inlined_cfuncs_")}` | #{cells[0]} | #{cells[1]} |"
end
