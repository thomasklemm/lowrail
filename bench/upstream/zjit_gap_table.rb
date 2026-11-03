# frozen_string_literal: true

# ZJIT gap census tables (docs/upstream/zjit-gap-census.md) from JIT stats JSON
# files written by ruby_bench_jit_stats.rb (key per_itr) or census/harness.rb
# stats (key per_op).
#   ruby SCRIPT NAME=ZJIT.json[,YJIT.json] ...
# Prints, per input: dynamic sends and side exits for both JITs, then the top
# ZJIT send-fallback, side-exit and compile counters, per iteration/operation.
require "json"

def load(path)
  return {} unless path && File.exist?(path)
  d = JSON.parse(File.read(path))
  d["per_itr"] || d["per_op"]
end

def top(h, prefix, n, skip: [])
  h.select { |k, _| k.start_with?(prefix) && !skip.include?(k) }.sort_by { -_2 }.first(n)
end

inputs = ARGV.map { |a| name, files = a.split("=", 2); [name, *files.split(",")] }
puts "| | ZJIT sends | ZJIT dynamic | YJIT dynamic | ZJIT side exits | YJIT side exits | ZJIT compiled ISEQs | invalidation ms |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
inputs.each do |name, z, y|
  zh, yh = load(z), load(y)
  ydyn = yh.select { |k, _| k.start_with?("send_") || k.start_with?("invokesuper_") || k.start_with?("invokeblock_") }
  printf("| %s | %.0f | %.0f | %s | %.0f | %s | %.1f | %.2f |\n", name, zh["send_count"].to_f, zh["dynamic_send_count"].to_f,
    yh.empty? ? "" : format("%.0f", ydyn.values.sum), zh["side_exit_count"].to_f,
    yh.empty? ? "" : format("%.0f", yh["side_exit_count"].to_f), zh["compiled_iseq_count"].to_f,
    zh["invalidation_time_ns"].to_f / 1e6)
end
inputs.each do |name, z, _|
  zh = load(z)
  puts "\n#{name}"
  [["send_fallback_", 14], ["exit_", 12], ["compile_error_", 5], ["unspecialized_send_def_type_", 5],
   ["complex_arg_pass_", 6], ["invokeblock_handler_", 5], ["getivar_fallback_", 4], ["setivar_fallback_", 4]].each do |prefix, n|
    rows = top(zh, prefix, n)
    next if rows.empty?
    puts "  #{prefix}: " + rows.map { |k, v| format("%s %.0f", k.delete_prefix(prefix), v) }.join(", ")
  end
end
