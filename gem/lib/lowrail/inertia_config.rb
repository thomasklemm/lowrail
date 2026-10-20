# frozen_string_literal: true

module Lowrail
  module Passes
    # Schema specialization, not a configuration/result cache. The original
    # method stays below Variant, including when a fact or shape declines.
    module InertiaConfig
      PASS = "inertia/config_bind"
      SINGLETON_METHODS = Kernel.instance_method(:singleton_methods)
      KEYS = Hash.instance_method(:keys)
      DEFAULT = Hash.instance_method(:default)
      DEFAULT_PROC = Hash.instance_method(:default_proc)
      IDENTITY = Hash.instance_method(:compare_by_identity?)

      module Variant
        def bind_controller(controller)
          if ::Ractor.current.equal?(::Ractor.main) &&
              ::Lowrail::Passes::InertiaConfig.valid?(self, @options)
            bound = ::InertiaRails::Configuration.allocate
            bound.instance_variable_set(:@controller, controller)
            bound.instance_variable_set(:@options, {**@options})
            bound
          else
            super
          end
        end
      end

      class << self
        def install(units)
          @unit = units.find { _1["pass"] == PASS }
        end

        def activate
          return unless @unit
          data = @unit.fetch("data")
          return unless Gem.loaded_specs["inertia_rails"]&.version.to_s == data.fetch("gem_version")
          return unless data.fetch("sources").all? { |path, sha| Manifest.sha256_file(path) == sha }
          klass = ::InertiaRails::Configuration
          return if klass < Variant
          original = klass.instance_method(:bind_controller)
          return unless original.source_location == data.fetch("original") && original.owner.equal?(klass) && klass.public_method_defined?(:bind_controller)
          schema = klass::OPTION_NAMES
          return unless schema.instance_of?(Array) && schema.frozen? && SINGLETON_METHODS.bind_call(schema).empty? &&
            schema.all? { Symbol === _1 } && !schema.include?(:controller) && schema.map(&:to_s) == data.fetch("keys")
          @id, @klass, @original, @schema = @unit.fetch("id"), klass, original, schema
          # Setup may be called after boot. Seed the shared weak override
          # tracker for preexisting #class stubs too. Later changes go through
          # Guard's normal hooks. No heap walk or reflection on the hot path.
          [klass, Hash].each do |type|
            ObjectSpace.each_object(type) do |object|
              Guard.note_override(object, :class) if SINGLETON_METHODS.bind_call(object).include?(:class)
            end
          end
          # Mutations of public configuration invalidate the method-fact cache;
          # revalidation then copies the new live values, never a boot snapshot.
          mutations = Module.new
          (schema.map { :"#{_1}=" } + %i[merge! with_defaults]).each do |name|
            parameter = name.to_s.end_with?("=") ? "value" : "config"
            mutations.module_eval <<~RUBY, __FILE__, __LINE__ + 1
              def #{name}(#{parameter})
                super
              ensure
                ::Lowrail::Passes::InertiaConfig.invalidate
              end
            RUBY
          end
          klass.prepend(mutations)
          klass.prepend(Variant)
        rescue StandardError, ScriptError => e
          Lowrail.debug("Inertia config declined: #{e.class}: #{e.message}")
        end

        def invalidate
          return unless ::Ractor.current.equal?(::Ractor.main)
          Guard.state[@id] = nil if @id
        end

        def valid?(config, options)
          state = Guard.state
          if state[@id].nil?
            state[@id] = Guard.validate(@id) &&
              @klass.instance_method(:bind_controller).super_method == @original &&
              @unit.fetch("facts").all? do |fact|
                holder = Object.const_get(fact.fetch("receiver"))
                holder = holder.singleton_class if fact["singleton"]
                holder.instance_method(fact.fetch("method")).original_name.to_s == fact.fetch("original_name")
              end
          end
          ok = state[@id] && ::InertiaRails::Configuration.equal?(@klass) &&
            @klass::OPTION_NAMES.equal?(@schema) && !@klass.const_defined?(:Configuration, false) &&
            config.class.equal?(@klass) && options.class.equal?(::Hash) &&
            DEFAULT.bind_call(options).nil? && DEFAULT_PROC.bind_call(options).nil? &&
            !IDENTITY.bind_call(options) && @schema == KEYS.bind_call(options)
          Stats.count(@id, !!ok) if defined?(Stats) && Stats.enabled?
          ok
        end
      end
    end
  end
end
