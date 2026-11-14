# ruby zstats_diff.rb OLD_DIR NEW_DIR : ZJIT/YJIT per-iteration counters, 11-03 receipts (stats/BENCH/{zjit,yjit}.json) vs round 2 (~/w/stats/{zjit,yjit}-BENCH.json)
require "json"
old, new = ARGV
keys = %w[dynamic_send_count side_exit_count send_fallback_send_polymorphic_fallback getivar_fallback_no_profile_missing_ic
  getivar_fallback_no_side_exits send_fallback_invokeblock_not_specialized send_fallback_invokeblock_polymorphic_miss
  send_fallback_send_block_arg_not_nil send_fallback_send_megamorphic send_fallback_one_or_more_complex_arg_pass
  send_fallback_sendforward_not_specialized send_fallback_send_not_optimized_need_permission send_fallback_super_complex_args_pass
  send_fallback_send_not_optimized_method_type_optimized dynamic_getivar_count]
%w[railsbench lobsters shipit].each do |b|
  o = JSON.parse(File.read("#{old}/stats/#{b}/zjit.json"))["per_itr"]; n = JSON.parse(File.read("#{new}/zjit-#{b}.json"))["per_itr"]
  oy = JSON.parse(File.read("#{old}/stats/#{b}/yjit.json"))["per_itr"]; ny = JSON.parse(File.read("#{new}/yjit-#{b}.json"))["per_itr"]
  puts "== #{b}"
  keys.each { |k| printf("  %-55s %10.0f %10.0f %+8.1f%%\n", k, o[k].to_f, n[k].to_f, o[k].to_f.zero? ? 0 : (n[k].to_f / o[k].to_f - 1) * 100) }
  %w[num_send_dynamic side_exit_count num_getivar_megamorphic].each { |k| printf("  yjit %-50s %10.0f %10.0f\n", k, oy[k].to_f, ny[k].to_f) }
end
