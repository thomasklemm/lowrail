# Rank ZJIT counters from harness.rb JSON files for docs/upstream/zjit-stats-2026-11-18.md.
#   ruby rank.rb [--limit N] NAME=FILE.json ...
# Prints, per counter family, the counters per measured iteration for each run (side exits,
# send fallbacks, not-inlined C methods, ...) and compile failures from boot through warmup.
limit = ARGV.include?("--limit") ? Integer(ARGV[ARGV.index("--limit") + 1]) : 15
require "json"
runs = ARGV.grep(/=/).map { |a| n, f = a.split("=", 2); [n, JSON.parse(File.read(f))] }

def fmt(v) = v.nil? ? "-" : (v >= 100 ? v.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse : v.round(1).to_s)

puts "runs: " + runs.map { |n, j| "#{n} (#{j["ms_per_itr"]} ms/itr)" }.join(", ")
puts runs.first[1]["ruby"]
puts
puts "## totals per iteration"
%w[zjit_insn_count total_insn_count ratio_in_zjit side_exit_count dynamic_send_count optimized_send_count
   iseq_optimized_send_count inline_cfunc_optimized_send_count non_variadic_cfunc_optimized_send_count
   variadic_cfunc_optimized_send_count dynamic_getivar_count dynamic_setivar_count compiled_iseq_count
   failed_iseq_count compile_error_out_of_memory].each do |k|
  puts [k.ljust(42), *runs.map { |_, j| fmt(j["per_itr"][k]).rjust(12) }].join
end

families = {
  "exit_" => "side exits", "send_fallback_" => "send fallback reasons",
  "not_inlined_cfuncs_" => "not inlined C methods", "unspecialized_send_def_type_" => "unspecialized send method types",
  "unspecialized_super_def_type_" => "unspecialized super method types",
  "uncategorized_fallback_yarv_insn_" => "uncategorized fallback YARV insns",
  "send_direct_fallback_context_" => "SendDirect fallback contexts",
  "complex_arg_pass_" => "complex argument passing", "getivar_fallback_" => "getivar fallbacks",
  "setivar_fallback_" => "setivar fallbacks", "inline_reject_" => "inline rejections",
}
families.each do |pre, title|
  keys = runs.flat_map { |_, j| j["per_itr"].keys.grep(/\A#{pre}/) }.uniq
  next if keys.empty?
  keys.sort_by! { |k| -runs.sum { |_, j| j["per_itr"][k].to_f } }
  puts
  puts "## #{title} (#{pre}*, per iteration)"
  keys.first(limit).each { |k| puts [k.delete_prefix(pre).ljust(48), *runs.map { |_, j| fmt(j["per_itr"][k]).rjust(12) }].join }
end
%w[compile_error_ unhandled_yarv_insn_ unhandled_hir_insn_].each do |pre|
  keys = runs.flat_map { |_, j| j["boot_warmup"].keys.grep(/\A#{pre}/) }.uniq
  next if keys.empty?
  keys.sort_by! { |k| -runs.sum { |_, j| j["boot_warmup"][k].to_f } }
  puts
  puts "## #{pre}* (cumulative, boot through warmup; window per iteration in brackets)"
  keys.first(limit).each do |k|
    puts [k.delete_prefix(pre).ljust(48), *runs.map { |_, j| "#{fmt(j["boot_warmup"][k])} (#{fmt(j["per_itr"][k] || 0)})".rjust(16) }].join
  end
end
