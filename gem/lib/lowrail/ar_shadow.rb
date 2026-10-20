# frozen_string_literal: true

module Lowrail
  # Test/canary oracle. Compile through Rails, but stop before select_all can
  # touch the query cache, instrument SQL, instantiate rows or run callbacks.
  module ARShadow
    class Mismatch < StandardError; end

    class PlanningConnection
      attr_reader :statement

      def initialize(connection)
        @connection = connection
      end

      def select_all(arel, name = nil, binds = [], **)
        sql, binds = @connection.send(:to_sql_and_binds, arel, binds)
        @statement = [name, sql, binds.map { ARShadow.bind(_1) }]
        nil
      end
    end

    class << self
      def enabled? = %w[1 strict].include?(ENV["LOWRAIL_SHADOW"])
      def counts = (@counts ||= Hash.new(0))
      def mismatches = (@mismatches ||= [])

      def bind(attribute)
        type = attribute.type
        value = attribute.value_for_database
        [attribute.name, type.class.name, type.type, type.limit, type.precision, type.scale,
          attribute.value_before_type_cast.class.name, attribute.value_before_type_cast,
          value.class.name, value]
      end

      def statement(model, connection, sql, binds = [])
        planner = PlanningConnection.new(connection)
        model._query_by_sql(planner, sql, binds)
        planner.statement
      end

      def relation(scope)
        return nil if scope.instance_variable_get(:@none) || scope.where_clause.contradiction?
        scope.model.with_connection { statement(scope.model, _1, scope.arel) }
      end

      def compare(pass, expected, actual)
        counts[pass] += 1
        return true if expected == actual
        entry = { "pass" => pass, "expected" => expected, "actual" => actual }
        mismatches << entry
        mismatches.shift if mismatches.size > 100
        # Ruby inspection also handles binary/invalid-encoding bind values;
        # a diagnostic must not introduce a JSON serialization exception.
        warn "[lowrail] AR shadow mismatch: #{entry.inspect}"
        raise Mismatch, "#{pass}: Rails planning differs (see AR shadow mismatch)" if ENV["LOWRAIL_SHADOW"] == "strict"
        false
      end

      def query(plan, model, connection, sql, binds, scope)
        compare(plan, relation(scope), statement(model, connection, sql, binds))
      end

      # Instantiation never bypasses SQL planning. Check its only cached
      # planning input against the live Rails recipe, without allocating a
      # second record, casting its values or invoking callbacks twice.
      def instantiate(model, builder)
        live = model.attributes_builder
        compare("active_record/instantiate", [live.types, live.default_attributes],
          [builder.types, builder.default_attributes])
      end

      def preload(records, spec)
        tree = ActiveRecord::Associations::Preloader::Branch.new(parent: nil, association: nil,
          children: spec, associate_by_default: true, scope: nil)
        tree.preloaded_records = records
        Preload.new(tree.children)
      end
    end

    class Preload
      def initialize(branches)
        @branches = branches
      end

      def statements(groups)
        groups.filter_map do |loaders|
          next if loaders.empty?
          query = loaders.first.loader_query
          records = ActiveRecord::Associations::Preloader::Association::LoaderRecords.new(loaders, query)
          keys = records.send(:keys_to_load)
          next if keys.empty?
          ARShadow.relation(query.scope.where(query.association_key_name => keys))
        end
      end

      def check(groups)
        return if @disabled
        # Rails Batch's live scheduling, including empty branches, is the
        # oracle rather than a second traversal of Lowrail's cached steps.
        loaders = @branches.flat_map(&:runnable_loaders)
        future = @branches.flat_map { |b| b.future_classes - b.runnable_loaders.map(&:klass) }.map(&:table_name).uniq
        selected = loaders.reject { future.include?(_1.table_name) }
        selected = loaders if selected.empty?
        @groups = selected.group_by { [_1.loader_query, _1.klass] }.values
        @disabled = !ARShadow.compare("active_record/preload_plans", statements(@groups), statements(groups))
      end

      def advance(groups)
        return if @disabled
        # Reuse only the rows just fetched by the real execution. No second
        # query, instantiation or callback. The real loaders already associated
        # the shared owners, so run only marks the oracle loaders complete.
        @groups.zip(groups.reject(&:empty?)).each do |expected, actual|
          rows = actual.flat_map(&:preloaded_records).uniq(&:__id__)
          expected.each { _1.load_records(rows); _1.run }
        end
        finished, pending = @branches.partition(&:done?)
        @branches = pending + finished.flat_map(&:children)
      end
    end
  end
end
