# frozen_string_literal: true

require_relative "preload_facts"

module Lowrail
  # Structural templates only. Every call makes fresh Rails Association and
  # LoaderRecords objects; the cached Relations are never executed themselves.
  module PreloadPlans
    Node = Struct.new(:edge, :children, :parent)

    class << self
      def install(manifest)
        unit = manifest.units.find { _1["pass"] == "active_record/preload_plans" }
        return unless unit
        @unit = unit.fetch("id")
        @facts = unit.fetch("preload_facts")
        @plans = {}
        @edges = {}
        @lock = Mutex.new
        if defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load)
          ActiveSupport.on_load(:after_initialize) { Lowrail::PreloadPlans.activate }
          return
        end
        # ActiveSupport is not loaded yet when setup runs through RUBYOPT.
        # TracePoint is removed at the first Rails boot, not on the hot path.
        @boot = TracePoint.new(:end) do |tp|
          if tp.self.is_a?(Class) && tp.self.name == "Rails::Application"
            @boot.disable
            ActiveSupport.on_load(:after_initialize) { Lowrail::PreloadPlans.activate }
          end
        end
        @boot.enable
      end

      def activate
        return unless defined?(ActiveRecord::Associations::Preloader)
        return unless Rails.version == @facts["rails_version"]
        require "digest"
        return unless @facts["sources"].all? { |p, sha| File.file?(p) && Digest::SHA256.file(p).hexdigest == sha }
        # Force autoloads before installing a module/hit counting a unit.
        ActiveRecord::Associations::Preloader::Association
        @originals = @facts["originals"].to_h do |f|
          name = f.fetch("method").to_sym
          raise ArgumentError, "preloader changed" unless PreloadFacts.method_fact(ActiveRecord::Associations::Preloader, name) == f
          [name, ActiveRecord::Associations::Preloader.instance_method(name)]
        end
        ActiveRecord::Associations::Preloader.prepend(Hook)
      rescue StandardError, ScriptError => e
        Lowrail.debug("preload plans disabled: #{e.class}: #{e.message}")
      end

      def plan(records, spec)
        return unless guard_ok?
        return unless Array === records && !records.empty?
        root = records.first.class
        return unless records.all? { _1.instance_of?(root) }
        key = [root, normalize(spec)]
        return unless key.last
        @lock.synchronize do
          p = @plans[key]
          # A structural scheduling decline can always stay on Rails, even
          # after facts change. It is not a specialization to revalidate.
          return if p == false
          # Rebuild on structural change, but only against recorded boot facts.
          @plans.delete(key) if p && !p.valid?
          return @plans[key] if @plans[key]
          # Includes specs can be constructed dynamically. Bound retained plan
          # structures; a full cache simply uses Rails, never evicts app data.
          return if @plans.size >= 256
          built = build(key.last, root)
          @plans[key] = built unless built.nil?
          built || nil
        end
      rescue StandardError => e
        Lowrail.debug("preload plan declined: #{e.class}: #{e.message}")
        nil
      end

      def hit
        Stats.count(@unit, true) if defined?(Stats) && Stats.enabled?
      end

      def guard_ok?
        return false unless Lowrail.enabled?
        state = Guard.state
        return state[@unit] unless state[@unit].nil?
        state[@unit] = Guard.validate(@unit) && @originals.all? do |name, original|
          m = ActiveRecord::Associations::Preloader.instance_method(name)
          m = m.super_method while m && m.owner == Hook
          m == original
        end
      end

      # Same Array.wrap/Array traversal as Rails Branch; copy containers so
      # mutating an includes spec cannot corrupt a cache key or stored tree.
      def normalize(spec)
        case spec
        when Symbol then spec
        when String then spec.dup.freeze
        when Array
          a = spec.map { normalize(_1) }
          a.freeze if a.all?
        when Hash
          a = spec.map { |k, v| [normalize(k), v.nil? ? [] : normalize(v)] }
          a.to_h.freeze if a.all? { |k, v| (Symbol === k || String === k) && v }
        when nil then [].freeze
        end
      end

      def build(spec, root)
        nodes = []
        visit = lambda do |children, owner, parent|
          Array.wrap(children).flat_map do |a|
            Array(a).map do |name, child|
              r = owner._reflect_on_association(name.to_sym)
              return nil unless r
              label = "#{owner.name}##{r.name}"
              expected = @facts["edges"][label] or return nil
              edge = @edges[label]
              edge = nil unless edge&.valid?
              @edges[label] = edge ||= Edge.new(owner, r, expected, @facts["models"])
              return nil unless edge.valid?
              node = Node.new(edge, [], parent)
              nodes << node
              node.children = visit.call(child, r.klass, node)
              return nil unless node.children
              node
            end
          end
        end
        roots = visit.call(spec, root, nil)
        if roots
          plan = Plan.new(roots, nodes, spec)
          plan.valid? ? plan : false
        end
      end
    end

    class Edge
      attr_reader :owner, :reflection, :scope, :reflection_scope, :query, :target

      def initialize(owner, reflection, expected, models)
        @owner, @reflection, @target = owner, reflection, reflection.klass
        raise ArgumentError, "uncertified association" if PreloadFacts.decline(reflection)
        raise ArgumentError, "reflection changed" unless PreloadFacts.reflection(reflection) == expected
        [owner, target].each do |k|
          raise ArgumentError, "schema changed" unless PreloadFacts.model(k) == models[k.name]
        end
        @columns = [owner.columns_hash, target.columns_hash]
        @types = [owner.attribute_types, target.attribute_types]
        @model_facts = Marshal.load(Marshal.dump([owner, target].map { |k|
          [k.table_name, k.primary_key, k.connection_specification_name, k.polymorphic_name, k.inheritance_column]
        }))
        @keys = [reflection.join_primary_key, reflection.join_foreign_key, reflection.type]
        @options = Marshal.load(Marshal.dump(PreloadFacts.value(reflection.options)))
        @scope_proc = reflection.scope
        @scope_name = PreloadFacts.scope_name(reflection)&.dup
        @reflection_scope = reflection.join_scopes(target.arel_table, target.predicate_builder, target).inject(target.unscoped, &:merge!)
        @scope = target.scope_for_association
        @scope.where!(reflection.type => owner.polymorphic_name) if reflection.type
        @scope.merge!(@reflection_scope) unless @reflection_scope.empty_scope?
        @query = ActiveRecord::Associations::Preloader::Association::LoaderQuery.new(@scope, reflection.join_primary_key)
      end

      def valid?
        owner._reflect_on_association(reflection.name).equal?(reflection) &&
          reflection.klass.equal?(target) && [reflection.join_primary_key, reflection.join_foreign_key, reflection.type] == @keys &&
          owner.columns_hash.equal?(@columns[0]) && target.columns_hash.equal?(@columns[1]) &&
          owner.attribute_types.equal?(@types[0]) && target.attribute_types.equal?(@types[1]) &&
          target.default_scopes.empty? && !target.current_scope &&
          reflection.scope.equal?(@scope_proc) && PreloadFacts.scope_name(reflection) == @scope_name &&
          PreloadFacts.value(reflection.options) == @options &&
          [owner, target].each_with_index.all? { |k, i|
            [k.table_name, k.primary_key, k.connection_specification_name, k.polymorphic_name, k.inheritance_column] == @model_facts[i]
          }
      rescue StandardError
        false
      end

      def loader(records)
        l = ActiveRecord::Associations::Preloader::Association.new(target, records, reflection, nil, reflection_scope, true)
        # Association#scope is public on the returned loader. Do not expose a
        # cached prototype that a caller could mutate or load with row data.
        l.instance_variable_set(:@scope, scope.spawn)
        l
      end
    end

    class Plan
      attr_reader :spec

      def initialize(roots, nodes, spec)
        @roots, @nodes = roots, nodes
        @spec = spec
        # Rails Batch postpones loaders whose table appears later in a tree.
        # A branch's own runnable class is excluded, even if it recurs below.
        # Decline inter-branch dependencies: empty owner sets can change that
        # schedule at runtime. Independent frontiers have fixed query groups.
        pending = roots.dup
        @steps = []
        until pending.empty?
          future = pending.flat_map { |node|
            (descendants(node).map { _1.edge.target }.uniq - [node.edge.target]).map(&:table_name)
          }
          if pending.size > 1 && pending.any? { future.include?(_1.edge.target.table_name) }
            Lowrail.debug("preload plan declined: data-dependent inter-branch schedule")
            # Only a fallback marker, not these edges, will be cached.
            @steps = nil
            return
          end
          groups = pending.group_by { |n| [n.edge.query, n.edge.target] }.values
          @steps << groups
          pending = pending.flat_map(&:children)
        end
      end

      def descendants(node)
        node.children.flat_map { [_1] + descendants(_1) }
      end

      def valid? = @steps && @nodes.all? { _1.edge.valid? }

      def call(records)
        loaders = {}.compare_by_identity
        @steps.each do |groups|
          groups.each do |nodes|
            active = nodes.filter_map do |node|
              owners = node.parent ? loaders[node.parent]&.preloaded_records : records
              next if !owners || owners.empty?
              # An STI subclass or custom instantiator appeared after planning.
              return nil unless owners.all? { _1.instance_of?(node.edge.owner) }
              loaders[node] = node.edge.loader(owners)
            end
            nodes.first.edge.query.load_records_in_batch(active) unless active.empty?
          end
        end
        PreloadPlans.hit
        @roots.filter_map { loaders[_1] }
      end
    end

    module Hook
      def initialize(records:, associations:, scope: nil, available_records: [], associate_by_default: true)
        @lowrail_plan = if scope.nil? && (available_records.nil? || available_records.empty?) && associate_by_default
          PreloadPlans.plan(records, associations)
        end
        return super unless @lowrail_plan
        @records, @associations, @scope = records, associations, scope
        @available_records, @associate_by_default = [], true
      end

      def call
        if @lowrail_plan && PreloadPlans.guard_ok? && @lowrail_plan.valid? && (result = @lowrail_loaders || @lowrail_plan.call(records))
          return @lowrail_loaders = result
        end
        super
      end

      def branches
        if @lowrail_plan && !@tree
          @tree = ActiveRecord::Associations::Preloader::Branch.new(parent: nil, association: nil,
            children: @lowrail_plan.spec, associate_by_default: associate_by_default, scope: scope)
          @tree.preloaded_records = records
          # A caller preparing loaders before #call owns that Rails tree.
          @lowrail_plan = nil unless @lowrail_loaders
        end
        super
      end

      def loaders
        @lowrail_loaders || super
      end
    end
  end
end
