# Lead totals for docs/upstream/zjit-iseq-leads.md from --zjit-stats-iseq JSONs (census apps and ruby-bench).
# ruby bench/upstream/zjit_iseq_leads.rb  (reads .lowrail/private/zjit-iseq/{apps,rb}/*.json)
require "json"
load_short = File.read("bench/upstream/zjit_iseq_rank.rb")[/def short.*?"@app\/"\)/m]
eval(load_short)
data = { apps: Dir[".lowrail/private/zjit-iseq/apps/*.json"], rb: Dir[".lowrail/private/zjit-iseq/rb/*.json"] }
rows = data.transform_values { |fs| fs.map { d = JSON.parse(File.read(_1)); [d["app"], d["ops"].to_f, d["stats"]] } }
LEADS = [
  ["yield in Array#each", /^send_fallback_invokeblock_/, /^each@<internal:array>/],
  ["yield in Array#map", /^send_fallback_invokeblock_/, /^map@<internal:array>/],
  ["BasicObject#!=", /^send_fallback_send_polymorphic/, /^!=@<internal:basic_object>/],
  ["protected: OrderedOptions#_get", /need_permission/, /ordered_options\.rb/],
  ["protected: any", /need_permission/, //],
  ["Kernel#send: Arel visit", /method_type_optimized/, /visitors\/visitor\.rb/],
  ["Kernel#send: any", /method_type_optimized/, //],
  ["delegate (...): WhereClause#empty?", /sendforward_not_specialized/, /where_clause\.rb:8$/],
  ["sendforward: any", /sendforward_not_specialized/, //],
  ["&block: any", /block_arg_not_nil/, //],
  ["&block: _read_attribute", /block_arg_not_nil/, /^_read_attribute@/],
  ["&block: monitor", /block_arg_not_nil/, /^mon_synchronize@/],
  ["super w/ block exit: any", /^exit_unhandled_block_arg/, //],
  ["super w/ block exit: fetch_or_store", /^exit_unhandled_block_arg/, /^fetch_or_store@/],
  ["invalidated constant exit: any", /^exit_patchpoint_stable_constant_names/, //],
  ["invalidated patchpoint exits: any", /^exit_patchpoint_/, //],
  ["singleton_class_seen: any", /singleton_class_seen/, //],
  ["singleton_class_seen: IndexedRow#fetch", /singleton_class_seen/, /indexed_row\.rb/],
  ["setivar no_side_exits: any", /^setivar_fallback_no_side_exits/, //],
  ["guard_type_failure exits: any", /^exit_guard_type_failure/, //],
  ["complex_arg_pass: any", /^send_fallback_one_or_more_complex_arg_pass/, //],
  ["getivar no_profile_missing_ic", /^getivar_fallback_no_profile_missing_ic/, //],
  ["getivar no_side_exits", /^getivar_fallback_no_side_exits/, //],
  ["send poly fallback", /^send_fallback_send_polymorphic_fallback/, //],
  ["send megamorphic", /^send_fallback_send_megamorphic/, //],
]
LEADS.each do |name, cre, ire|
  out = rows.map do |set, rs|
    per = rs.map { |app, ops, st| v = st.sum { |k, n| next 0 unless k.start_with?("iseq:"); c, i = k.delete_prefix("iseq:").split(":", 2); (c =~ cre && short(i).sub(/\A.*?@/) { $& } =~ ire) ? n : 0 }; [app, v / ops] }.select { _2 > 0 }
    set == :apps ? format("%2d/10 apps, %7.1f/op mean over reached", per.size, per.sum(&:last) / [per.size, 1].max) : "rb " + %w[railsbench lobsters shipit].map { |b| (per.to_h[b] || 0).round }.join(" / ")
  end
  puts format("%-38s %s | %s", name, *out)
end
