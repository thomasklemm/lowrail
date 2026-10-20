# frozen_string_literal: true

require_relative "ar_plan_facts"
require_relative "ar_guard"
require_relative "ar_shadow"

module Lowrail
  # The original Association#find_target and Relation#exec_queries still run.
  # Only the Arel/SQL compilation in an internal, final scoped relation is reused.
  module ARPlans
    class << self
      def install(manifest)
        @unit = manifest.units.find { _1["pass"] == "active_record/ar_plans" }
        return unless @unit
        AR.install
        @plans = {}.compare_by_identity
        if defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load)
          ActiveSupport.on_load(:after_initialize) { Lowrail::ARPlans.activate }
        else
          @boot = TracePoint.new(:end) do |tp|
            if tp.self.is_a?(Class) && tp.self.name == "Rails::Application"
              @boot.disable
              ActiveSupport.on_load(:after_initialize) { Lowrail::ARPlans.activate }
            end
          end
          @boot.enable
        end
      end

      def activate
        data = @unit.fetch("ar_plans")
        return unless defined?(Lowrail::AR) && Rails.version == data.fetch("rails_version")
        require "digest"
        return unless data.fetch("sources").all? { |path, sha| File.file?(path) && Digest::SHA256.file(path).hexdigest == sha }
        @originals = data.fetch("originals").map do |fact|
          holder = Object.const_get(fact.fetch("receiver"))
          name = fact.fetch("method").to_sym
          actual = PreloadFacts.method_fact(holder, name).merge("receiver" => fact.fetch("receiver"))
          raise ArgumentError, "query hook changed" unless actual == fact
          [holder, name, holder.instance_method(name)]
        end
        data.fetch("edges").each do |label, edge|
          owner = Object.const_get(edge.fetch("owner"))
          reflection = owner._reflect_on_association(edge.fetch("name"))
          next unless reflection && PreloadFacts.reflection(reflection) == edge.fetch("reflection")
          next unless [owner, reflection.klass].all? { PreloadFacts.model(_1) == data.fetch("models").fetch(_1.name) }
          @plans[reflection] = Plan.new(reflection, edge.fetch("scope"))
        end
        ActiveRecord::Associations::Association.prepend(AssociationHook)
        ActiveRecord::Relation.prepend(RelationHook)
      rescue StandardError, ScriptError => e
        Lowrail.debug("AR plans disabled: #{e.class}: #{e.message}")
        @plans.clear
      end

      def tag(association, scope)
        plan = @plans[association.reflection]
        return unless plan && Lowrail.enabled?
        scope.instance_variable_set(:@lowrail_ar_plan, [plan, association])
      rescue StandardError => e
        Lowrail.debug("AR plan declined: #{e.class}: #{e.message}")
      end

      def guard_ok?
        state = Guard.state
        id = @unit.fetch("id")
        return state[id] unless state[id].nil?
        state[id] = Guard.validate(id) && @originals.all? do |holder, name, original|
          current = holder.instance_method(name)
          current = current.super_method while current && [RelationHook, AssociationHook].include?(current.owner)
          current == original
        end
      end

      def count(ok)
        Stats.count(@unit.fetch("id"), ok) if defined?(Stats) && Stats.enabled?
      end
    end

    class Plan
      def initialize(reflection, scope_info)
        @reflection, @owner, @model = reflection, reflection.active_record, reflection.klass
        @scope_info = scope_info
        raise ArgumentError, "uncertified scope" if ARPlanFacts.decline(reflection, scope_info)
        @tables = [@owner.table_name.dup, @model.table_name.dup]
        @columns = [@owner.columns_hash, @model.columns_hash]
        @types = [@owner.attribute_types, @model.attribute_types]
        @defaults = [@owner.default_scopes, @model.default_scopes]
        @role, @shard = @model.current_role, @model.current_shard
        @adapter = @model.with_connection(&:class)
        # Metadata reads can materialize Rails' lazy schema/type state.
        @epochs = [AR.epoch(@owner), AR.epoch(@model)]
        @cache = {}.compare_by_identity
        @lock = Mutex.new
      end

      def valid?(association, scope)
        association.owner.instance_of?(@owner) && association.klass.equal?(@model) &&
          Object.const_get(@owner.name).equal?(@owner) && Object.const_get(@model.name).equal?(@model) &&
          @epochs == [AR.epoch(@owner), AR.epoch(@model)] &&
          @owner.table_name == @tables[0] && @model.table_name == @tables[1] &&
          @owner.columns_hash.equal?(@columns[0]) && @model.columns_hash.equal?(@columns[1]) &&
          @owner.attribute_types.equal?(@types[0]) && @model.attribute_types.equal?(@types[1]) &&
          @owner.current_scope.nil? && @model.current_scope.nil? &&
          @owner.global_current_scope.nil? && @model.global_current_scope.nil? &&
          @owner.default_scopes.equal?(@defaults[0]) && @model.default_scopes.equal?(@defaults[1]) &&
          !@owner.scope_attributes? && !@model.scope_attributes? &&
          @model.current_role == @role && @model.current_shard == @shard &&
          !scope.eager_loading? && ActiveRecord.query_transformers.empty? &&
          (!@scope_info.key?("generated_name") || PreloadFacts.scope_name(@reflection) == @scope_info["generated_name"]) &&
          !ActiveRecord::StatementCache.unsupported_value?(association.owner._read_attribute(@reflection.join_foreign_key))
      rescue NameError
        false
      end

      def execute(association, scope)
        @model.with_connection do |connection|
          return nil unless connection.instance_of?(@adapter)
          cached = @lock.synchronize do
            cached = @cache[connection]
            if !cached || cached[0] != connection.prepared_statements
              # Same placeholder association scope used by Rails find_target.
              as = ActiveRecord::Associations::AssociationScope.create { ActiveRecord::StatementCache::Substitute.new }
              relation = association.send(:target_scope).merge!(as.scope(association))
              query, binds = connection.cacheable_query(ActiveRecord::StatementCache, relation.arel)
              cached = @cache[connection] = [connection.prepared_statements, query, ActiveRecord::StatementCache::BindMap.new(binds)]
            end
            cached
          rescue StandardError => e
            Lowrail.debug("AR plan construction declined: #{e.class}: #{e.message}")
            nil
          end
          return nil unless cached
          _, builder, bind_map = cached
          values = ActiveRecord::Associations::AssociationScope.get_bind_values(association.owner, @reflection.chain)
          binds = bind_map.bind(values)
          sql = builder.sql_for(binds, connection)
          ARShadow.query("active_record/ar_plans", @model, connection, sql, binds, scope) if ARShadow.enabled?
          result = @model._query_by_sql(connection, sql, binds, preparable: true, allow_retry: builder.retryable)
          ARPlans.count(true)
          result
        end
      end
    end

    module AssociationHook
      private

      def skip_statement_cache?(scope)
        skipped = super
        ARPlans.tag(self, scope) if skipped
        skipped
      end
    end

    module RelationHook
      def initialize_copy(other)
        @lowrail_ar_plan = nil
        super
      end

      private

      def assert_modifiable!
        @lowrail_ar_plan = nil
        super
      end

      def exec_main_query(async: false)
        if (tag = @lowrail_ar_plan) && !async
          plan, association = tag
          if ARPlans.guard_ok? && plan.valid?(association, self)
            result = plan.execute(association, self)
            return result if result
          end
          ARPlans.count(false)
        end
        super
      end
    end
  end
end
