# frozen_string_literal: true

# Bet F, EXPLORATION ONLY. Never required by lowrail/setup. This is a bounded
# final-relation compiler, not a certificate for skipping application scopes or
# relation construction. Method/source mutation is NOT certified by this study.
require_relative "../../gem/lib/lowrail/ar_shadow"

module ARCallsite
  class Decline < StandardError; end
  Plan = Struct.new(:sql, :preparable, :retryable, :dependencies)
  ALLOWED = %i[where order limit offset select distinct includes preload references
    readonly strict_loading skip_query_cache reverse_order].freeze

  class << self
    attr_accessor :enabled, :shadow, :counting
    attr_reader :plans, :counts, :refusals

    def install(sql: true, lean: true)
      raise "Ruby 4.0.7 / Rails 8.1.4 required" unless RUBY_VERSION == "4.0.7" && ActiveRecord.version.to_s == "8.1.4"
      @plans, @counts, @refusals, @materializers = {}, Hash.new(0), Hash.new(0), {}
      @sql, @lean = sql, lean
      self.enabled = true
      self.shadow = ENV["AR_CALLSITE_SHADOW"] == "1"
      self.counting = true
      ActiveRecord::Relation.prepend(QueryHook) if sql && !(ActiveRecord::Relation < QueryHook)
      ActiveRecord::Base.singleton_class.prepend(RowHook) if lean && !(ActiveRecord::Base.singleton_class < RowHook)
    end

    def count(name)
      @counts[name] += 1 if counting
    end

    def decline(reason)
      @refusals[reason] += 1 if counting
      nil
    end

    def prepare(scope, connection)
      raise Decline, "unprepared_connection" unless connection.prepared_statements
      raise Decline, "adapter" unless connection.instance_of?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
      raise Decline, "query_transformer" unless ActiveRecord.query_transformers.empty?
      raise Decline, "relation_values" unless (scope.values.keys - ALLOWED).empty?
      # Includes/preload stay with Rails' continuation. Joined eager loads do not.
      raise Decline, "joined_eager_load" if scope.eager_loading?
      shape = Shape.new
      values = scope.values.except(:includes, :preload, :references, :readonly, :strict_loading,
        :skip_query_cache, :reverse_order)
      key_values = values.map do |name, value|
        [name, case name
        when :where then shape.node(value.ast)
        when :limit, :offset then !value.nil?
        else shape.node(value)
        end]
      end
      # Rails visits predicates first, then LIMIT/OFFSET, then projection/order.
      # Supported projections/orders cannot contain bind nodes.
      [:limit, :offset].each do |name|
        value = values[name]
        next unless value
        raise Decline, "limit_type" unless value.instance_of?(Integer)
        shape.binds << ActiveModel::Attribute.with_cast_value(name.to_s.upcase, value, ActiveRecord::Type.default_value)
      end
      model = scope.model
      key = [connection, connection.visitor, model, model.arel_table.object_id, model.columns_hash.object_id,
        model.enumerate_columns_in_select_statements, model.ignored_columns.dup, key_values]
      [key, shape.binds]
    end

    # Can be called at boot for an explicitly constructed final relation. The
    # generic hook discovers/fills on first execution; it cannot invent a boot
    # execution of an arbitrary app scope without changing application effects.
    def prime(scope)
      scope.model.with_connection do |connection|
        key, binds = prepare(scope, connection)
        compile(scope, connection, key, binds)
      end
    rescue Decline => error
      decline(error.message)
    end

    def compile(scope, connection, key, binds)
      return @plans[key] if @plans.key?(key)
      raise Decline, "capacity_256" if @plans.size >= 256
      sql, native_binds, preparable, retryable = connection.send(:to_sql_and_binds, scope.arel)
      # A fill must prove its extracted layout, including types and before-cast
      # values, against the real visitor before any query can use the plan.
      raise "bind extraction differs" unless native_binds.map { Lowrail::ARShadow.bind(_1) } == binds.map { Lowrail::ARShadow.bind(_1) }
      count("fills")
      # Retain identity-keyed metadata until this bounded cache is discarded;
      # schema reset must not let object_id recycling alias an older plan.
      @plans[key] = Plan.new(sql, preparable, retryable,
        [scope.model.arel_table, scope.model.columns_hash, scope.model.attribute_types])
    end

    def query(scope, connection)
      key, binds = prepare(scope, connection)
      plan = compile(scope, connection, key, binds)
      if shadow
        # Use a fresh spawn: an Arel cached by the fill is not an independent
        # live planner. This does not execute SQL or instantiate a second row.
        expected = Lowrail::ARShadow.relation(scope.spawn)
        actual = Lowrail::ARShadow.statement(scope.model, connection, plan.sql, binds)
        raise "SQL/binds differ" unless expected == actual
        count("shadow_checks")
      end
      [plan, binds]
    rescue Decline => error
      decline(error.message)
    end

    def materialize(model, values, additional_types)
      builder = model.attributes_builder
      entry = @materializers[model]
      if !entry || !entry[0].equal?(builder)
        types, defaults = builder.types, builder.default_attributes
        # Generate the per-model row constructor, but retain the exact Rails
        # LazyAttributeSet class, actual type objects and default recipe. Eager
        # per-column attributes would change missing/default/lazy-cast behavior.
        factory = eval("->(row, extra) { ActiveModel::LazyAttributeSet.new(row, types, extra, defaults) }",
          binding, "ar-callsite:#{model.name}", 1)
        entry = @materializers[model] = [builder, factory]
      end
      count("rows")
      entry[1].call(values, additional_types)
    end

    def sql? = enabled && @sql
    def lean? = enabled && @lean
  end

  class Shape
    attr_reader :binds
    def initialize = @binds = []

    def native_type!(type)
      name = type.class.name.to_s
      raise Decline, "custom_type" unless name.start_with?("ActiveModel::Type::", "ActiveRecord::Type::",
        "ActiveRecord::ConnectionAdapters::SQLite3Adapter::") || name == "ActiveRecord::Enum::EnumType"
      raise Decline, "custom_type" unless type.singleton_methods.empty?
      native_type!(type.subtype) if type.respond_to?(:subtype)
    end

    def node(value)
      case value
      when ActiveModel::Attribute
        native_type!(value.type)
        raise Decline, "unboundable" if value.respond_to?(:unboundable?) && value.unboundable?
        # A nil equality is IS NULL and has no placeholder.
        return [:nil, value.name, value.type.object_id] if value.nil?
        @binds << value
        [:bind, value.class.name, value.name, value.type.object_id]
      when Arel::Attributes::Attribute
        raise Decline, "table_alias" unless value.relation.instance_of?(Arel::Table)
        [:column, value.relation.name.dup, value.relation.table_alias, value.name.to_s]
      when Arel::Nodes::HomogeneousIn
        native_type!(value.attribute.type_caster)
        cast = value.casted_values
        @binds.concat(cast.map(&value.proc_for_binds))
        [:in, node(value.attribute), value.type, cast.size]
      when Arel::Nodes::And
        [:and, value.children.map { node(_1) }]
      when Arel::Nodes::Or
        [:or, value.children.map { node(_1) }]
      when Arel::Nodes::Equality, Arel::Nodes::NotEqual,
        Arel::Nodes::GreaterThan, Arel::Nodes::GreaterThanOrEqual,
        Arel::Nodes::LessThan, Arel::Nodes::LessThanOrEqual
        [value.class.name, node(value.left), node(value.right)]
      when Arel::Nodes::Grouping, Arel::Nodes::Ascending, Arel::Nodes::Descending
        [value.class.name, node(value.expr)]
      when Arel::Nodes::SqlLiteral
        [:sql, value.to_s.dup, value.retryable]
      when String
        raise Decline, "string_subclass" unless value.instance_of?(String)
        [:string, value.dup]
      when Symbol, Integer, true, false, nil
        value
      when Array
        value.map { node(_1) }
      else
        raise Decline, "node:#{value.class.name}"
      end
    end
  end

  # Explicit pure call-site specimen. The caller, not a source analysis, asserts
  # that invoking this block at boot is safe. Never installed in app requests.
  # It prices removing chain spawning separately from final-query reuse.
  class DirectSite
    def initialize(model, arity:, &chain)
      @model, @arity, @chain = model, arity, chain
      @template = chain.call(*Array.new(arity) { ActiveRecord::StatementCache::Substitute.new })
      raise Decline, "direct_site_shape" unless (@template.values.keys - ALLOWED).empty? && !@template.eager_loading?
      model.with_connection do |connection|
        raise Decline, "unprepared_connection" unless connection.prepared_statements
        @connection, @visitor = connection, connection.visitor
        @sql, binds, @preparable, @retryable = connection.send(:to_sql_and_binds, @template.arel)
        @bind_map = ActiveRecord::StatementCache::BindMap.new(binds)
      end
      @defaults, @types = model.default_scopes.dup, model.attribute_types
      @role, @shard = model.current_role, model.current_shard
    end

    def call(*values)
      valid = ARCallsite.sql? && values.size == @arity && values.none? { ActiveRecord::StatementCache.unsupported_value?(_1) } &&
        @model.default_scopes == @defaults && @model.attribute_types.equal?(@types) &&
        @model.current_scope.nil? && @model.global_current_scope.nil? &&
        @model.current_role == @role && @model.current_shard == @shard && ActiveRecord.query_transformers.empty?
      @model.with_connection do |connection|
        valid &&= connection.equal?(@connection) && connection.visitor.equal?(@visitor) && connection.prepared_statements
      end
      return @chain.call(*values).to_a unless valid
      binds = @bind_map.bind(values)
      return @chain.call(*values).to_a if binds.any? { _1.respond_to?(:unboundable?) && _1.unboundable? }
      relation = @template.spawn
      relation.instance_variable_set(:@ar_callsite_direct, [Plan.new(@sql, @preparable, @retryable), binds])
      relation.to_a
    end
  end

  module QueryHook
    private
    def exec_main_query(async: false)
      if (direct = @ar_callsite_direct) && ARCallsite.sql? && !async
        plan, binds = direct
        return skip_query_cache_if_necessary do
          model.with_connection { model._query_by_sql(_1, plan.sql, binds, preparable: plan.preparable, allow_retry: plan.retryable) }
        end
      end
      return super unless ARCallsite.sql? && !async && !@none && !where_clause.contradiction?
      model.with_connection do |connection|
        planned = ARCallsite.query(self, connection)
        return super unless planned
        plan, binds = planned
        skip_query_cache_if_necessary do
          ARCallsite.count("queries")
          model._query_by_sql(connection, plan.sql, binds, preparable: plan.preparable, allow_retry: plan.retryable)
        end
      end
    end
  end

  module RowHook
    private
    def instantiate_instance_of(klass, attributes, column_types = {}, &block)
      return super unless ARCallsite.lean? && klass.method(:attributes_builder).owner == ActiveRecord::ModelSchema::ClassMethods
      # init_with_attributes retains find -> initialize callbacks, yield and
      # internals. STI discrimination still occurs in Rails' caller.
      klass.allocate.init_with_attributes(ARCallsite.materialize(klass, attributes, column_types), &block)
    end
  end
end

# The shared native harness calls this symmetrically after natural Rails boot.
module NativeBench
  module Exploration
    def self.install(config:, state:, arm:)
      ARCallsite.install(sql: config.fetch("ar_sql", true), lean: config.fetch("ar_lean", true))
      ARCallsite.enabled = arm == "on"
      ARCallsite.counting = ENV.key?("LOWRAIL_STATS")
      ARCallsite.shadow = ARCallsite.counting
      if ARCallsite.counting
        require "digest"
        @sql_count, @sql_digest = 0, Digest::SHA256.new
        ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
          payload = args.last
          @sql_count += 1
          @sql_digest << Marshal.dump([payload[:sql].b, payload[:name],
            payload[:binds].map { Lowrail::ARShadow.bind(_1) }, !!payload[:cached]])
        end
      end
    end

    def self.counts
      {"completed" => ARCallsite.counts.dup, "refusals" => ARCallsite.refusals.dup,
        "cached_plans" => ARCallsite.plans.size, "sql_events" => @sql_count,
        "sql_sha256" => @sql_digest&.hexdigest}
    end
  end
end
