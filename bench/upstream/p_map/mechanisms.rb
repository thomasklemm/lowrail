# frozen_string_literal: true

# Inclusive share of server time per mechanism and app: a running worker
# sample counts for a mechanism when any frame on its stack matches (labels,
# or "file:" patterns on file paths). Mean over each app's workloads.
#   ruby mechanisms.rb RECEIPT.json...
require_relative "report"

MECHANISMS = {
  "allow_browser (UserAgent parse)" => /\AActionController::AllowBrowser#allow_browser\z/,
  "Rack::ETag body digest" => /\ARack::ETag#digest_body\z/,
  "Notifications Event CPU/GC/alloc sampling" => /\AActiveSupport::Notifications::Event#now_(cpu|gc|allocations)\z/,
  "Structured events → log subscribers" => /\AActiveSupport::(StructuredEventSubscriber|EventReporter)#|::StructuredEventSubscriber#/,
  "CSRF token mask/HMAC" => /\AActionController::RequestForgeryProtection#(form_authenticity_token|masked_authenticity_token|verified_request\?|valid_authenticity_token\?)\z/,
  "Cookie jar encrypt/sign" => /\AActiveSupport::(MessageEncryptor|MessageVerifier)#/,
  "Request ID (SecureRandom.uuid)" => /\AActionDispatch::RequestId#make_request_id\z/,
  "SQLite prepare (uncached statement)" => /\ASQLite3::Statement#initialize\z/,
  "SQLite step/rows" => /\ASQLite3::Statement#(each|step|to_a)\z/,
  "PG exec + result" => /\APG::Connection#(exec_params|exec_prepared|exec|async_exec|send_query_params|send_query_prepared|get_result|block)\z|\APG::Result#/,
  "Query cache" => /\AActiveRecord::ConnectionAdapters::QueryCache#(select_all|lookup_sql_cache|cache_sql)\z/,
  "Arel → SQL (to_sql visitor)" => /\AArel::Visitors::ToSql#compile\z|\AArel::Visitors::Visitor#accept\z/,
  "Relation building (spawn/where/merge)" => /\AActiveRecord::(SpawnMethods#(spawn|merge|except|only)|QueryMethods#(where|order|includes|joins|select|limit|preload|eager_load)|Relation::Merger#merge)\z/,
  "Default scopes / scoping" => /\AActiveRecord::Scoping::Default::ClassMethods#|\AActiveRecord::Scoping::Named::ClassMethods#(all|default_scoped|scope_for_association)\z/,
  "Record instantiation" => /\AActiveRecord::Relation#instantiate_records\z|\AActiveRecord::Persistence::ClassMethods#instantiate_instance_of\z/,
  "Association preloading" => /\AActiveRecord::Associations::Preloader#call\z/,
  "Association reader (singular/collection)" => /\AActiveRecord::Associations::(Singular|Collection)Association#reader\z|\AActiveRecord::Associations::CollectionProxy#(load_target|records)\z/,
  "Time zone conversion (TimeWithZone)" => /\AActiveSupport::TimeWithZone#|\ATZInfo::/,
  "i18n translate" => /\AI18n::Base#(translate|t|localize|l)\z/,
  "Tag helpers (tag/content_tag)" => /\AActionView::Helpers::TagHelper#(tag|content_tag)\z|\AActionView::Helpers::TagHelper::TagBuilder#/,
  "URL helpers (url_for/path)" => /UrlHelper::OptimizedUrlHelper#call\z|\AActionDispatch::Routing::RouteSet#(url_for|path_for)\z|\AActionDispatch::Routing::PolymorphicRoutes#/,
  "Asset path helpers" => /\AActionView::Helpers::AssetUrlHelper#asset_path\z/,
  "Partial/collection render" => /\AActionView::(PartialRenderer|CollectionRenderer|ObjectRenderer)#render\z/,
  "Template/partial lookup" => /\AActionView::(LookupContext|PathSet|Resolver|FileSystemResolver)#|ViewPaths#/,
  "Fragment cache (cache helper)" => /\AActionView::Helpers::CacheHelper#cache\z/,
  "Cache store read/write" => /\AActiveSupport::Cache::Store#(read|write|fetch|read_multi|fetch_multi|write_multi)\z/,
  "JSON encode (to_json/render json)" => /\AActiveSupport::JSON::Encoding::JSONGemCoderEncoder#encode\z|\AActiveSupport::ToJsonWithActiveSupportEncoder#to_json\z|\AJSON::Ext::Generator::State#generate\z/,
  "Jbuilder" => /\AJbuilderTemplate#|\AJbuilder#/,
  "ActiveModel::Serializers" => /\AActiveModel::Serializer#|\AActiveModelSerializers::/,
  "Params parse + filter" => /\AActionDispatch::Request#(POST|GET|params|parameters|request_parameters|query_parameters)\z|\AActiveSupport::ParameterFilter#/,
  "Routing (recognize)" => /\AActionDispatch::Journey::Router#(serve|find_routes)\z/,
  "Session load/commit" => /\AActionDispatch::Session::(CookieStore|AbstractStore|AbstractSecureStore)#|\ARack::Session::Abstract::Persisted#(commit_session|load_session|context)\z/,
  "Cookie jar write (Set-Cookie)" => /\AActionDispatch::Cookies#call\z|\AActionDispatch::Cookies::CookieJar#write\z/,
  "Puma request parse + response write" => /\APuma::(Server#(process_client|uncork_socket|cork_socket|closed_socket\?)|Request#(handle_request|prepare_response|fast_write_str|fast_write_response|str_headers)|Response#|Client#(eagerly_finish|try_to_finish|parser_execute))/,
  "Validations" => /\AActiveModel::Validations#(valid\?|run_validations!)\z/,
  "Transactions + commit callbacks" => /\AActiveRecord::Transactions#with_transaction_returning_status\z/,
}.freeze

totals = Hash.new { |h, k| h[k] = {} }
apps = []
ARGV.each do |path|
  d = PMapReport.load(path)
  apps << d["app"]
  by, = PMapReport.attribute(d)
  interval_ms = d["interval_us"] / 1000.0
  matches = {}
  per = Hash.new { |h, k| h[k] = Hash.new(0.0) }
  d["threads"].each do |t|
    next unless t["name"].match?(/tp \d+\z/)
    t["samples"].each do |stack, category, window, cnt|
      next if window.nil? || category != 0
      hits = matches[stack] ||= begin
        labels = d["stacks"].fetch(stack.to_s).map(&:first).uniq
        MECHANISMS.select { |_, re| labels.any? { _1.match?(re) } }.keys
      end
      hits.each { per[window][_1] += cnt * interval_ms }
    end
  end
  MECHANISMS.each_key do |m|
    shares = d["windows"].each_index.map { |i| 100.0 * per[i][m] / by[i].values.sum }
    totals[m][d["app"]] = [shares.sum / shares.size, shares.max]
  end
end
puts "| Mechanism (inclusive) | #{apps.join(" | ")} | mean | apps ≥ 0.5% |"
puts "|---|#{"---:|" * (apps.size + 2)}"
totals.sort_by { |_, v| -v.values.sum { _1[0] } }.each do |m, v|
  mean = v.values.sum { _1[0] } / apps.size
  reach = v.count { _2[0] >= 0.5 }
  puts "| #{m} | #{apps.map { format("%.2f", v[_1][0]) }.join(" | ")} | #{format("%.2f", mean)} | #{reach} |"
end
