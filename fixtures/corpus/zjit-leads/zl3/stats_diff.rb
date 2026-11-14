# stats_diff.rb BASE.json HEAD.json : per-iteration ZJIT counters that differ, plus whole-process compile and memory.
require "json"
base, head = ARGV.map { JSON.parse(File.read(_1)) }
keys = %w[dynamic_send_count send_fallback_send_polymorphic_fallback send_fallback_send_megamorphic send_fallback_send_polymorphic
  send_fallback_send_no_profiles side_exit_count exit_polymorphic_send_miss compiled_iseq_count iseq_optimized_send_count
  inline_iseq_optimized_send_count zjit_insn_count getivar_fallback_no_side_exits setivar_fallback_no_side_exits]
keys.each do |k|
  b = base["per_itr"][k] || 0
  h = head["per_itr"][k] || 0
  printf("%-45s %14.1f %14.1f %+10.1f\n", k, b, h, h - b)
end
puts "-- whole process at end of warmup (before reset)"
(base["before_reset"].keys | head["before_reset"].keys).each do |k|
  printf("%-45s %14s %14s\n", k, base["before_reset"][k], head["before_reset"][k])
end
printf("%-45s %14s %14s\n", "vm_hwm_kb (end)", base["vm_hwm_kb"], head["vm_hwm_kb"])
puts "-- largest per-iteration counter moves"
all = (base["per_itr"].keys | head["per_itr"].keys).reject { _1.include?("@") || _1.end_with?("_ns") }
all.map { [_1, (head["per_itr"][_1] || 0) - (base["per_itr"][_1] || 0)] }.sort_by { -_2.abs }.first(25).each do |k, d|
  printf("%-55s %+14.1f\n", k, d)
end
