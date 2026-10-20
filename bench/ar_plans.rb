# frozen_string_literal: true

# Diagnostic only: does not install a pass or alter application methods.
# From a prepared corpus app: ruby --yjit ../../bench/ar_plans.rb
# Fresh-process interleaving is provided by bench/ar_plans_runs.rb.
require File.expand_path("config/environment", Dir.pwd)
require "json"

Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
abort "YJIT required" unless RubyVM::YJIT.enabled?

module ARPlanExperiment
  module_function

  # Deliberately conservative, full snapshots rather than a purported complete
  # invalidation protocol. This measures one guard design, not a lower bound on
  # every possible guard. No values, records, or execution results are cached.
  def metadata(model, connection)
    [Object.const_get(model.name), model.ancestors, model.singleton_class.ancestors,
      model.table_name.dup, model.primary_key, model.columns_hash, model.attribute_types,
      model.defined_enums.deep_dup, model.attribute_aliases.dup,
      model.default_scopes.dup, model.current_scope, model.global_current_scope,
      model.strict_loading_by_default, model.connection_pool, model.current_role, model.current_shard,
      connection, connection.class, connection.prepared_statements, connection.schema_cache,
      ActiveRecord.query_transformers.dup,
      model.reflect_on_all_associations.map { [_1, _1.options.deep_dup, _1.scope] }]
  end

  def definitions(model, relation)
    # A baseline certificate for code whose planning a StatementCache skips.
    # This is still insufficient for arbitrary scope closures/custom types.
    holders = [model.singleton_class, relation.class, ActiveRecord::QueryMethods,
      ActiveRecord::PredicateBuilder, ActiveRecord::Relation::WhereClause,
      ActiveRecord::Associations::AssociationScope, Arel::Visitors::ToSql,
      Arel::Visitors::SQLite, Arel::Visitors::PostgreSQL]
    holders.flat_map do |holder|
      (holder.instance_methods + holder.private_instance_methods + holder.protected_instance_methods).uniq.sort.map {
        [holder, _1, holder.instance_method(_1)]
      }
    end
  end

  def measure(name, block)
    500.times { block.call }
    GC.start
    count = 0
    objects = GC.stat(:total_allocated_objects)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    deadline = started + Float(ENV.fetch("BENCH_SECONDS", "2"))
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      block.call
      count += 1
    end
    { route: name, us_per_req: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1e6 / count,
      allocs_per_req: (GC.stat(:total_allocated_objects) - objects).fdiv(count) }
  end
end

case Rails.application.class.module_parent_name
when "Campfire"
  owner = Room.find_by!(name: "All Talk")
  model = Message
  relation = ->(id) { Message.where(room_id: id).order(:created_at).limit(10) }
  association = -> { owner.messages.ordered.limit(10).to_a }
  attribute = "room_id"
  read = ->(record) { record.room_id }
  write = ->(record, value) { record.room_id = value }
when "Pingcrm"
  owner = User.find_by!(email: "m0-inertia@example.test").account
  model = Organization
  relation = ->(id) { Organization.where(account_id: id, deleted_at: nil).order(:name).limit(10) }
  association = -> { owner.organizations.not_trashed.order(:name).limit(10).to_a }
  attribute = "name"
  read = ->(record) { record.name }
  write = ->(record, value) { record.name = value }
else
  abort "use the pinned Campfire or PingCRM corpus"
end

model.with_connection do |connection|
  # The relation is private to this experiment. Never replace an escaping
  # relation with StatementCache.execute's Array in a real lowering.
  statement = ActiveRecord::StatementCache.create(connection) do |params|
    relation.call(params.bind)
  end
  expected = relation.call(owner.id).map(&:attributes)
  raise "association query differs" unless association.call.map(&:attributes) == expected
  raise "statement query differs" unless statement.execute([owner.id], connection).map(&:attributes) == expected

  sample = relation.call(owner.id)
  metadata = ARPlanExperiment.metadata(model, connection)
  methods = ARPlanExperiment.definitions(model, sample)
  metadata_guard = -> { metadata == ARPlanExperiment.metadata(model, connection) }
  guard = -> {
    metadata_guard.call &&
      methods.all? { |holder, name, method| holder.instance_method(name) == method }
  }
  record = relation.call(owner.id).first or raise "fixture missing"
  type_map = model.attribute_types
  generated_reader = record.class.instance_method(attribute)
  writer_name = "#{attribute}=".to_sym
  generated_writer = record.class.instance_method(writer_name)
  value = read.call(record)
  attributes = record.instance_variable_get(:@attributes)
  attribute_guard = -> {
    record.instance_of?(model) && model.attribute_types.equal?(type_map) &&
      model.instance_method(attribute) == generated_reader && model.instance_method(writer_name) == generated_writer
  }
  cases = {
    "relation" => -> { relation.call(owner.id).to_a },
    "association" => association,
    "statement_unguarded" => -> { statement.execute([owner.id], connection) },
    "statement_metadata_guard" => -> { metadata_guard.call ? statement.execute([owner.id], connection) : relation.call(owner.id).to_a },
    "statement_snapshot_guard" => -> { guard.call ? statement.execute([owner.id], connection) : relation.call(owner.id).to_a },
    "metadata_guard_only" => -> { raise "unexpected guard rejection" unless metadata_guard.call },
    "snapshot_guard_only" => -> { raise "unexpected guard rejection" unless guard.call },
    "attribute_read_generated" => -> { read.call(record) },
    "attribute_read_direct" => -> { attributes.fetch_value(attribute) },
    "attribute_read_guarded" => -> { attribute_guard.call ? attributes.fetch_value(attribute) : read.call(record) },
    "attribute_write_generated" => -> { write.call(record, value) },
    "attribute_write_direct" => -> { attributes.write_from_user(attribute, value) },
    "attribute_write_guarded" => -> { attribute_guard.call ? attributes.write_from_user(attribute, value) : write.call(record, value) }
  }
  names = ENV.fetch("BENCH_CASES", cases.keys.join(",")).split(",")
  names.reverse! if ENV["BENCH_REVERSE"] == "1"
  result = ActiveRecord::Base.uncached { names.map { ARPlanExperiment.measure(_1, cases.fetch(_1)) } }
  puts JSON.pretty_generate(result)
  File.write(ENV.fetch("BENCH_JSON"), JSON.pretty_generate(result)) if ENV["BENCH_JSON"]
end
