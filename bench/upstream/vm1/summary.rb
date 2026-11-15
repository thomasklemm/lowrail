# frozen_string_literal: true

# Counters per request from jit_stats.rb runs: mean over each app's
# workloads, then over apps (each app weighs the same).
#   ruby summary.rb [--top N] [--keys a,b] DIR... (DIR holds APP.json; a ce2- prefix marks CE2 runs)
require "json"

top = ARGV.include?("--top") ? Integer(ARGV[ARGV.index("--top") + 1]) : 40
keys = ARGV.include?("--keys") ? ARGV[ARGV.index("--keys") + 1].split(",") : nil
dirs = ARGV.reject { _1.start_with?("--") || _1.match?(/\A\d+\z/) || _1.include?(",") }

runs = dirs.flat_map do |dir|
  set = File.basename(dir).start_with?("ce2-") ? "CE2 " : ""
  Dir["#{dir}/*.json"].sort.map { |path| j = JSON.parse(File.read(path)); [set + j["app"], j] }
end
abort "no runs" if runs.empty?

REASON = /\A(send_|invokesuper_|invokeblock_|guard_|exit_|expandarray_|getivar_|setivar_|definedivar_|opt_|oaref_|gbpp_|objtostring_|leave_|cold_|invalidat|side_exit|total_exit|num_send_dynamic|num_send_polymorphic|num_send_megamorphic|num_throw|dynamic_|send_fallback|compiled_iseq_count|compiled_block_count|failed_|not_compiled|unhandled_|compile_error)/
SKIP = /(_ns|_bytes|_size|_time)\z|\Anum_send_(cfunc|iseq|known)|code_region|alloc_size/

means = Hash.new { |h, k| h[k] = {} }
runs.each do |app, j|
  w = j["windows"]
  w.flat_map { _1["stats"].keys }.uniq.each do |k|
    next if keys ? !keys.include?(k) : (!k.match?(REASON) || k.match?(SKIP))
    means[k][app] = w.sum { _1["stats"].fetch(k, 0) } / w.size
  end
end
apps = runs.map(&:first)
rows = means.map { |k, per| [k, per, apps.sum { per.fetch(_1, 0) } / apps.size, apps.count { per.fetch(_1, 0) >= 1 }] }
rows = rows.sort_by { -_3 }
rows = rows.first(top) unless keys
puts (["counter (per request)"] + apps + ["mean", "apps >= 1"]).join("\t")
rows.each do |k, per, mean, reach|
  puts ([k] + apps.map { per.fetch(_1, 0).round(1) } + [mean.round(1), reach]).join("\t")
end
