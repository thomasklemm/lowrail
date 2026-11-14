# ruby r59141_report.rb ROOT APP  -- ZJIT per-ISEQ counters (r2s-main vs r2s-parent) and YJIT globals (r2y-*) per op
# for the attribute reader path (rails/rails#59141). Reader ISEQs are grouped: `_read_attribute_N` after #59141,
# per-name readers (`title`, ...) before it are found by their path (attribute_methods/read.rb generated code).
require "json"
root, app = ARGV
READER = /\A(_read_attribute(_\d+|_at!|!)?|fetch_value(_at)?!?|_read_attribute)\z/

def group(label, loc)
  return "_read_attribute_N" if label =~ /\A_read_attribute_\d+\z/
  return label if label =~ READER
  return "per-name reader" if loc.include?("active_record/attribute_methods/read.rb") || loc.include?("(eval at") && loc.include?("read.rb")
  nil
end

def zjit(root, label, app)
  d = JSON.parse(File.read(File.join(root, label, "#{app}-zjit.json")))
  agg = Hash.new(0)
  d["per_op"].each do |k, v|
    next unless k.start_with?("iseq:")
    _, counter, loc = k.split(":", 3)
    g = group(loc.split("@").first, loc) or next
    agg[[g, counter]] += v
  end
  [agg, d]
end

zm, dm = zjit(root, "r2s-main", app)
zp, dp = zjit(root, "r2s-parent", app)
puts "## #{app}: ZJIT per-ISEQ counters per op (parent c48c154e3f -> main 50c54eed06)"
puts "OOM: main #{dm.dig("totals", "compile_error_out_of_memory").to_i}, parent #{dp.dig("totals", "compile_error_out_of_memory").to_i}"
puts "| ISEQ | counter | parent | main |"
puts "|---|---|---:|---:|"
(zm.keys | zp.keys).sort_by { -(zm[_1] + zp[_1]) }.first(30).each do |k|
  printf("| `%s` | `%s` | %.1f | %.1f |\n", k[0], k[1], zp[k], zm[k])
end
%w[send_fallback_send_polymorphic_fallback send_fallback_send_megamorphic getivar_fallback_no_side_exits
   getivar_fallback_no_profile_missing_ic send_fallback_send_block_arg_not_nil side_exit_count dynamic_send_count
   dynamic_getivar_count].each do |c|
  printf("global %-45s parent %10.1f main %10.1f\n", c, dp["per_op"][c].to_f, dm["per_op"][c].to_f)
end
%w[r2y-parent r2y-main].each do |l|
  f = File.join(root, l, "#{app}-yjit.json")
  next unless File.exist?(f)
  y = JSON.parse(File.read(f))["per_op"]
  keys = y.keys.grep(/megamorphic|polymorphic|send_dynamic|num_send\b|num_send_dynamic|getivar_megamorphic|getivar_poly|side_exit_count|inline_code_size|invalidation/)
  puts "#{l} YJIT: " + keys.sort.map { "#{_1}=#{format("%.1f", y[_1])}" }.join(" ")
end
