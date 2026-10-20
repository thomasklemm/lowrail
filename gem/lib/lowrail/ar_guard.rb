# frozen_string_literal: true

module Lowrail
  # Invalidation epochs for Active Record plans.
  #
  # A pass that computes something once per model (a query plan, an
  # instantiation recipe) stores `Lowrail::AR.epoch(klass)` next to it and
  # reuses it only while the epoch is unchanged. The epoch of a class grows
  # whenever Rails changes what a plan may have read from that class or one
  # of its ancestors:
  #
  #   * schema and attributes: reload_schema_from_cache (reset_column_information,
  #     attribute, enum, serialize, table_name=, ignored_columns=, ...),
  #     load_schema!, attribute, define_attribute, decorate_attributes,
  #     primary_key=, reset_primary_key;
  #   * default_scope;
  #   * callbacks: set_callbacks (set_callback, skip_callback, reset_callbacks);
  #   * reflections: Reflection.add_reflection, clear_reflections_cache;
  #   * connections, for every class: establish_connection, connects_to,
  #     remove_connection.
  #
  # Method redefinitions are not tracked here: those are method facts, reset
  # by Lowrail::Guard. Per-call state (current_scope, connected_to role and
  # shard, query cache, strict_loading on a relation) is not an event either;
  # passes check it on every call.
  #
  # Cost: epoch(klass) is one identity-hash lookup and one comparison. A bump
  # walks the class's descendants; that happens at boot and when a test
  # changes a model, never per request.
  module AR
    EPOCHS = {}.compare_by_identity
    LOCK = Mutex.new
    @counter = 0
    @global = 0
    @events = 0

    # Class-level methods whose call may change a plan's inputs.
    # define_attribute changes types/defaults without a schema reload;
    # reset_primary_key re-derives the key (8.1 goes through primary_key=,
    # other versions may not). Names missing in a Rails version are skipped.
    CLASS_EVENTS = %i[reload_schema_from_cache load_schema! attribute define_attribute decorate_attributes
                      primary_key= reset_primary_key default_scope set_callbacks clear_reflections_cache].freeze
    GLOBAL_EVENTS = %i[establish_connection connects_to remove_connection].freeze

    class << self
      attr_reader :events

      def epoch(klass)
        e = EPOCHS[klass]
        g = @global
        e && e > g ? e : g
      end

      def bump(klass)
        LOCK.synchronize do
          @events += 1
          value = (@counter += 1)
          EPOCHS[klass] = value
          descendants_of(klass).each { |d| EPOCHS[d] = value }
        end
      end

      def bump_all
        LOCK.synchronize do
          @events += 1
          @global = (@counter += 1)
        end
      end

      def installed? = !!@hooked

      # Safe to call more than once and before Active Record is loaded.
      def install
        return if @install_requested
        @install_requested = true
        return hook! if defined?(::ActiveRecord::Base)
        if defined?(::ActiveSupport) && ::ActiveSupport.respond_to?(:on_load)
          ::ActiveSupport.on_load(:active_record) { Lowrail::AR.hook! }
          return
        end
        # Under RUBYOPT Active Support is not loaded yet; wait for it. The
        # TracePoint is removed as soon as the lazy-load hooks exist.
        @wait = TracePoint.new(:end) do
          next unless defined?(::ActiveSupport) && ::ActiveSupport.respond_to?(:on_load)
          @wait.disable
          ::ActiveSupport.on_load(:active_record) { Lowrail::AR.hook! }
        end
        @wait.enable
      end

      def hook!
        return if @hooked
        @hooked = true
        base = ::ActiveRecord::Base.singleton_class
        base.prepend(hooks_for(base, CLASS_EVENTS) { |klass| AR.bump(klass) })
        base.prepend(hooks_for(base, GLOBAL_EVENTS) { |_| AR.bump_all })
        reflection = ::ActiveRecord::Reflection.singleton_class
        if reflection.method_defined?(:add_reflection) || reflection.private_method_defined?(:add_reflection)
          reflection.prepend(Module.new do
            def add_reflection(ar, *, **, &)
              super
            ensure
              ::Lowrail::AR.bump(ar) if ar.is_a?(Class)
            end
          end)
        end
      end

      private

      # A module defining each existing method as `super` plus the event,
      # with the original visibility (private class methods stay private).
      def hooks_for(target, names, &event)
        mod = Module.new
        names.each do |name|
          visibility =
            if target.public_method_defined?(name) then :public
            elsif target.protected_method_defined?(name) then :protected
            elsif target.private_method_defined?(name) then :private
            end
          next unless visibility
          mod.define_method(name) do |*args, **kw, &blk|
            super(*args, **kw, &blk)
          ensure
            event.call(self)
          end
          mod.send(visibility, name)
        end
        mod
      end

      def descendants_of(klass)
        return klass.descendants if klass.respond_to?(:descendants)
        klass.subclasses.flat_map { [_1, *descendants_of(_1)] }
      end
    end
  end
end
