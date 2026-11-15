# frozen_string_literal: true

# QB1: P-MAP's "AR: query building" layer split by path and stage, from
# p_map/profile.rb receipts (Vernier wall mode through Puma):
#   ruby stages.rb RECEIPT.json...            markdown tables
#   ruby stages.rb --json OUT RECEIPT.json... machine-readable shares
# A sample counts when P-MAP charges it to query building (self time). Its path
# is "statement cache" when StatementCache#execute is on the stack, "cache
# create" under StatementCache.create, and "built per query" otherwise. Its
# stage is the first that matches anywhere on the stack, in this order:
# visitor (Arel AST to SQL), binds, build_arel, association scope (the
# relation an association reader or preloader builds), where predicates
# (hash to Arel nodes), relation spawn/merge, then the rest (load, finder and
# calculation plumbing, query cache, query logs). Inclusive extras count every
# layer: bind type casting and the association scope a reader builds before it
# uses the statement cache.
require "json"
require_relative "../p_map/report"

module QBStages
  STAGES = [
    ["visitor (Arel to SQL)", %r{/arel/(?:visitors|collectors)/|#(?:to_sql_and_binds|cacheable_query)\b|TreeManager#to_sql}],
    ["binds", /QueryAttribute|StatementCache::(?:BindMap|PartialQuery|Query)|value_for_database|type_casted_binds|BindParam|build_bind_attribute|with_cast_value/],
    ["build_arel", /QueryMethods#(?:build_\w+|arel_columns?\w*|arel|order_column|table_name_matches\?)\b|Relation#arel\b/],
    ["association scope", /AssociationScope|Association#(?:scope|association_scope|target_scope)\b|Reflection#(?:join_scope|klass_join_scope|join_scopes)|scope_for_association|Preloader::Association#(?:scope|reflection_scope|build_scope)/],
    ["where predicates", /PredicateBuilder|TableMetadata|#build_where_clause|#sanitize_sql|#expand_hash_conditions|#process_\w+_args|#column_references/],
    ["relation spawn/merge", /#spawn\b|#initialize_copy|Merger|SpawnMethods|Relation\.create|Relation#initialize|WhereClause|QueryMethods#\w+!?\z|Scoping|ScopeRegistry|_exec_scope|default_scoped|#all\z|Delegation/],
  ].freeze

  module_function

  def path(frames)
    labels = frames.map(&:first)
    if labels.include?("ActiveRecord::StatementCache.create") then "cache create"
    elsif labels.include?("ActiveRecord::StatementCache#execute") then "statement cache"
    else "built per query"
    end
  end

  def stage(frames)
    STAGES.each { |name, re| return name if frames.any? { |label, file, _| label.match?(re) || file.match?(re) } }
    "other (load, finders, query cache, logs)"
  end

  def origin(frames)
    labels = frames.map(&:first)
    if labels.any? { _1.include?("Associations::Preloader") } then "preload"
    elsif labels.include?("ActiveRecord::Associations::Association#find_target") then "association reader"
    elsif labels.any? { _1.match?(/Associations::\w+Association#(?:reader|load_target|find|size|empty\?|exist)/) || _1.include?("CollectionProxy") } then "association collection"
    elsif labels.any? { _1.match?(/Core::ClassMethods#find(?:_by)?\z/) } then "Model.find/find_by"
    elsif labels.any? { _1.match?(/Calculations#|FinderMethods#exists\?/) } then "count/exists?/pluck"
    else "relation"
    end
  end

  AR_FILE = %r{/(?:activerecord|activemodel)/lib/}

  # The Active Record method the app (or a view, helper or gem) called: the
  # outermost Active Record frame below the innermost non-Active Record frame.
  def entry(frames)
    i = frames.index { |_, file, _| file != "<cfunc>" && !file.start_with?("<internal:") && !file.match?(AR_FILE) } or return "(no caller)"
    ar = frames[0...i].reverse.find { |_, file, _| file.match?(AR_FILE) }
    ar ? ar[0].sub(/\AActiveRecord::/, "") : "(no caller)"
  end

  def bind_cast?(frames) = frames.any? { |label, _, _| label.match?(/type_casted_binds|QueryAttribute#value_for_database|StatementCache::BindMap#bind/) }

  def assoc_scope_before_cache?(frames)
    labels = frames.map(&:first)
    i = labels.index("ActiveRecord::Associations::Association#find_target") or return false
    labels[0...i].any? { _1.match?(/Association#scope\z/) } && !labels[0...i].include?("ActiveRecord::StatementCache#execute") &&
      !labels[0...i].any? { _1.match?(/Relation#(?:to_a|load|records)\z/) }
  end

  # Per workload: server ms (P-MAP's denominator) and ms per [path, stage, origin] cell.
  def attribute(d)
    interval_ms = d["interval_us"] / 1000.0
    stacks = d["stacks"]
    total = Hash.new(0.0)
    cells = Hash.new { |h, k| h[k] = Hash.new(0.0) }
    extras = Hash.new { |h, k| h[k] = Hash.new(0.0) }
    d["threads"].each do |t|
      worker = t["name"].match?(/tp \d+\z/)
      puma = t["name"].match?(/\Apuma (srv|reactor)\z/)
      next unless worker || puma
      t["samples"].each do |stack, category, window, n|
        next if window.nil?
        frames = stacks.fetch(stack.to_s)
        ms = n * interval_ms
        if puma
          total[window] += ms if category == 0
          next
        end
        if category == 0
          total[window] += ms
          extras[window]["bind type casting (all layers)"] += ms if bind_cast?(frames)
          extras[window]["association scope built, then statement cache (all layers)"] += ms if assoc_scope_before_cache?(frames)
          next unless PMapLayers.layer(frames, d["app_root"]) == "AR: query building"
          cells[window][[path(frames), stage(frames), origin(frames), entry(frames)]] += ms
        elsif category != 2 && PMapLayers.in_request?(frames)
          total[window] += ms
        end
      end
    end
    d["windows"].each_with_index { |w, i| total[i] += w["gc_ns"] / 1e6 }
    d["windows"].each_with_index.map do |w, i|
      { name: w["name"], total_ms: total[i], requests: w["requests"],
        cells: cells[i].map { |(p, s, o, e), ms| { path: p, stage: s, origin: o, entry: e, share: 100.0 * ms / total[i] } },
        extras: extras[i].transform_values { 100.0 * _1 / total[i] } }
    end
  end

  def app_rows(path)
    d = PMapReport.load(path)
    { app: d["app"], set: File.basename(File.dirname(path)), workloads: attribute(d) }
  end

  # Mean over an app's workloads of the share in each group, then over apps.
  def mean_by(apps, &key)
    per_app = apps.map do |a|
      sums = Hash.new(0.0)
      a[:workloads].each { |w| w[:cells].each { |c| sums[key.call(c)] += c[:share] } }
      [a[:app], sums.transform_values { _1 / a[:workloads].size }]
    end.to_h
    keys = per_app.values.flat_map(&:keys).uniq
    keys.to_h { |k| [k, per_app.transform_values { _1.fetch(k, 0.0) }] }
  end

  def table(title, apps, &key)
    rows = mean_by(apps, &key)
    names = apps.map { _1[:app] }
    out = +"#{title}\n\n| | #{names.join(" | ")} | mean |\n|---|#{"---:|" * (names.size + 1)}\n"
    rows.sort_by { |_, v| -v.values.sum }.each do |k, v|
      vals = names.map { v.fetch(_1, 0.0) }
      out << "| #{Array(k).join(" · ")} | #{vals.map { format("%.2f", _1) }.join(" | ")} | #{format("%.2f", vals.sum / vals.size)} |\n"
    end
    vals = names.map { |n| rows.values.sum { _1.fetch(n, 0.0) } }
    out << "| **total** | #{vals.map { format("%.2f", _1) }.join(" | ")} | #{format("%.2f", vals.sum / vals.size)} |\n\n"
  end

  def extras_table(apps)
    names = apps.map { _1[:app] }
    keys = apps.flat_map { |a| a[:workloads].flat_map { _1[:extras].keys } }.uniq
    out = +"Inclusive, every layer (percent of server time)\n\n| | #{names.join(" | ")} | mean |\n|---|#{"---:|" * (names.size + 1)}\n"
    keys.each do |k|
      vals = apps.map { |a| a[:workloads].sum { _1[:extras].fetch(k, 0.0) } / a[:workloads].size }
      out << "| #{k} | #{vals.map { format("%.2f", _1) }.join(" | ")} | #{format("%.2f", vals.sum / vals.size)} |\n"
    end
    out
  end
end

if $PROGRAM_NAME == __FILE__
  json = ARGV.delete("--json") && ARGV.shift
  apps = ARGV.map { QBStages.app_rows(_1) }
  if json
    File.write(json, JSON.pretty_generate(apps))
  else
    puts QBStages.table("Query building by path (percent of server time)", apps) { _1[:path] }
    puts QBStages.table("Query building by stage", apps) { _1[:stage] }
    puts QBStages.table("Built per query, by stage", apps) { _1[:path] == "built per query" ? _1[:stage] : "(statement cache)" }
    puts QBStages.table("Query building by origin", apps) { _1[:origin] }
    puts QBStages.table("Path × origin", apps) { [_1[:path], _1[:origin]] }
    puts QBStages.extras_table(apps)
    puts
    rows = QBStages.mean_by(apps) { _1[:entry] }.sort_by { -_2.values.sum }.first(Integer(ENV.fetch("QB_ENTRIES", "30")))
    names = apps.map { _1[:app] }
    puts "Query building by entry point (top), percent of server time\n\n| | #{names.join(" | ")} | mean |\n|---|#{"---:|" * (names.size + 1)}"
    rows.each { |k, v| vals = names.map { v.fetch(_1, 0.0) }; puts "| #{k} | #{vals.map { format("%.2f", _1) }.join(" | ")} | #{format("%.2f", vals.sum / vals.size)} |" }
  end
end
