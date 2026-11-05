# Self Ir per iteration grouped by subsystem (file patterns), OLD vs NEW sampled
# windows (cg_profile.rb JSON; comma-separated files are averaged).
#   ruby cg_groups.rb OLD.json[,OLD2.json] NEW.json[,NEW2.json]
require "json"
G = {
  "attribute storage (IndexedRow, LazyAttributeSet, Result)" => %r{active_model/(indexed_row|attribute_set|attribute_set/builder|attribute|attribute_registration)\.rb|active_record/(result|attribute_methods/read|attribute_methods)\.rb|core_ext/enumerable\.rb},
  "schema context, Ractor-local lookups" => %r{model_schema(/schema_context)?\.rb|active_record/attributes\.rb|ractors\.rb|<internal:ractor>},
  "association routes, reflections, keys" => %r{association_route\.rb|reflection\.rb|active_record/key\.rb|associations/|associations\.rb},
  "connection pool lease, WeakKeyMap" => %r{connection_pool\.rb|weak_key_map\.rb|connection_handling\.rb|connection_handler\.rb},
  "query intents, database statements, adapter" => %r{query_intent\.rb|database_statements\.rb|abstract_adapter\.rb|query_cache\.rb|sqlite3},
  "relation building (query_methods, where, merger, predicate)" => %r{relation(/|\.rb)|arel/|predicate_builder|table_metadata|scoping},
  "routing, URL generation" => %r{action_dispatch/(routing|journey)|url_for|http/url},
  "Action Controller / Action Pack rest" => %r{action_controller|action_dispatch|abstract_controller|actionpack},
  "notifications, instrumentation, execution state" => %r{notifications|instrument|isolated_execution|subscriber|event_reporter|log_subscriber},
}
def self_by_file(paths) = paths.map { |p| JSON.parse(File.read(p))["methods"].each_with_object(Hash.new(0)) { |m, h| h[m["file"]] += m["self"] } }.then { |hs| hs.flat_map(&:keys).uniq.to_h { |k| [k, hs.sum { _1[k] } / hs.size] } }
a, b = ARGV.first(2).map { self_by_file(_1.split(",")) }
tot = Hash.new(0)
(a.keys | b.keys).each { |f| g = G.find { |_, re| f.match?(re) }&.first || (f.start_with?("GEM/") ? "gems" : f.start_with?("<cfunc>") ? "<no Ruby frame>" : "other (Ruby stdlib, app, rest of Rails)"); tot[g] += b.fetch(f, 0) - a.fetch(f, 0) }
tot.sort_by { -_2.abs }.each { |g, d| printf("%-62s %+8.1fM\n", g, d / 1e6) }
printf("%-62s %+8.1fM\n", "sum", tot.values.sum / 1e6)
