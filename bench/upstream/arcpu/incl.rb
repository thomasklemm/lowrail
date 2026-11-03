# Inclusive % (outermost occurrence per sample) for named frame patterns, per dump.
require "stackprof"
PATS = {
  "query cache keying (Store#compute_if_absent minus yield)" => nil,
  "Relation#exec_queries" => /ActiveRecord::Relation#exec_queries/,
  "_load_from_sql (instantiate)" => /Querying#_load_from_sql/,
  "Result#column_types" => /Result#column_types/,
  "build_arel" => /QueryMethods#build_arel/,
  "arel to_sql (Visitor#accept/compile)" => /Arel::Visitors::(Visitor#accept|ToSql#compile)|Arel::TreeManager#to_sql/,
  "to_sql_and_binds" => /DatabaseStatements#to_sql_and_binds/,
  "where/rewhere/build_where_clause" => /QueryMethods#(where|where!|build_where_clause)\b/,
  "PredicateBuilder" => /PredicateBuilder#/,
  "Merger#merge / Relation#merge" => /Merger#merge|SpawnMethods#merge/,
  "Relation spawn/new (Delegation.create, Relation#initialize/_copy)" => /Delegation::ClassMethods#create|Relation#initialize|Relation#initialize_copy|SpawnMethods#spawn/,
  "default scope (build_default_scope, has_default_scope?)" => /build_default_scope|has_default_scope\?/,
  "Relation#scoping/_scoping" => /Relation#_?scoping/,
  "Association#scope / AssociationScope" => /Association#scope\b|AssociationScope/,
  "StatementCache#execute" => /StatementCache#execute/,
  "StatementCache::BindMap#bind" => /BindMap#bind/,
  "connection_pool lookup (ConnectionHandling#connection_pool)" => /ConnectionHandling#connection_pool/,
  "with_connection/checkout/checkin" => /ConnectionPool#(checkout|checkin)|AbstractAdapter#(lease|expire)/,
  "Notifications instrument sql.active_record (Instrumenter#instrument under execute_intent)" => nil,
  "SQLite3 Statement step/prepare/bind (driver C)" => /SQLite3::(Statement|Database)#/,
  "perform_query (adapter, incl. driver)" => /DatabaseStatements#perform_query/,
  "type casting binds (type_casted_binds)" => /type_casted_binds|type_cast\b/,
  "Preloader#call" => /Preloader#call/,
  "LazyAttributeSet#fetch_value(!)" => /LazyAttributeSet#fetch_value/,
  "Core#init_with_attributes" => /Core#init_with_attributes/,
  "ActiveSupport::Notifications (any)" => /ActiveSupport::Notifications::(Instrumenter|Fanout)/,
}.compact
puts (["frame"] + ARGV.map { File.basename(_1, ".dump") }).join("\t")
res = ARGV.map do |path|
  d = Marshal.load(File.binread(path)); fr = d[:frames]; raw = d[:raw]
  nm = Hash.new { |h, a| f = fr[a]; h[a] = f ? f[:name].to_s : "" }
  hit = PATS.transform_values { 0 }
  m = PATS.to_h { |k, re| [k, Hash.new { |h, a| h[a] = nm[a].match?(re) }] }
  tot = 0; i = 0
  while i < raw.size
    l = raw[i]; s = raw[i + 1, l]; w = raw[i + 1 + l]; i += l + 2; tot += w
    PATS.each_key { |k| mk = m[k]; hit[k] += w if s.any? { mk[_1] } }
  end
  hit.transform_values { 100.0 * _1 / tot }
end
PATS.each_key { |k| puts ([k] + res.map { format("%.2f", _1[k]) }).join("\t") }
