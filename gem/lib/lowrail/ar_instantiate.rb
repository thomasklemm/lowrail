# frozen_string_literal: true

require_relative "ar_shadow"

module Lowrail
  # One ordinary singleton-class def (and ISeq) per model. Rails still owns
  # object initialization, lazy casting, callbacks and instrumentation.
  module ARInstantiate
    PASS = "active_record/instantiate"

    class << self
      def install(units)
        require_relative "ar_guard"
        AR.install
        @units = units
      end

      def activate
        require_relative "ar_guard"
        require "digest"
        @units.each do |unit|
          name = unit.fetch("ar_instantiate").fetch("model")
          if Rails.respond_to?(:autoloaders) && Rails.application
            Rails.autoloaders.each do |loader|
              loader.on_load(name) { |klass| activate_model(klass, unit) }
            end
          end
          # Even after initialization, forcing a model to load can run lazy
          # framework hooks and change other models' callbacks/SQL. Observe
          # existing constants only; Zeitwerk installs late models naturally.
          klass = name.split("::").inject(Object) do |owner, part|
            break if owner.autoload?(part) || !owner.const_defined?(part, false)
            owner.const_get(part, false)
          end
          activate_model(klass, unit) if klass
        end
      rescue LoadError => e
        Lowrail.debug("AR instantiate unavailable: #{e.message}")
      end

      def activate_model(klass, unit)
        data = unit.fetch("ar_instantiate")
        return unless Rails.version == data.fetch("rails_version")
        return unless data.fetch("sources").all? { |p, sha| File.file?(p) && Digest::SHA256.file(p).hexdigest == sha }
        original = klass.method(:_load_from_sql)
        original = original.super_method while original&.source_location&.first&.start_with?("lowrail:ar_instantiate:")
        return unless original_fact(original) == data.fetch("original")
        entry = Entry.new(klass, unit)
        klass.instance_variable_set(:@_lowrail_instantiate, entry)
        klass.singleton_class.class_eval(source(entry.id), "lowrail:ar_instantiate:#{klass.name}", 1)
      rescue StandardError, ScriptError => e
        Lowrail.debug("AR instantiate declined: #{e.class}: #{e.message}")
      end

      def original_fact(method)
        { "owner" => method.owner.name || method.owner.to_s,
          "source_location" => method.source_location }
      end

      def source(id)
        <<~RUBY
          # frozen_string_literal: true
          def _load_from_sql(result_set, &block)
            # Alpha's schema attributes are Ractor-local. Do not even read the
            # main Ractor's unshareable plan from a different Ractor.
            return super unless ::Ractor.current.equal?(::Ractor.main)
            plan = @_lowrail_instantiate
            unless plan && plan.klass.equal?(self) && plan.valid?
              ::Lowrail::ARInstantiate.count(#{id}, false)
              return super
            end
            return [] if result_set.empty?
            column_types = result_set.column_types
            unless column_types.empty?
              column_types = column_types.reject { |key, _| attribute_types.key?(key) }
            end
            message_bus = ::ActiveSupport::Notifications.instrumenter
            payload = { record_count: result_set.length, class_name: name }
            message_bus.instrument("instantiation.active_record", payload) do
              if result_set.includes_column?(inheritance_column)
                result_set.indexed_rows.map do |record|
                  ::Lowrail::ARInstantiate.count(#{id}, false)
                  instantiate(record, column_types, &block)
                end
              else
                result_set.indexed_rows.map do |record|
                  # A subscriber or a preceding row's block/callback may change
                  # methods or schema. Resume Rails row loading, never replay rows.
                  if plan.current?
                    ::Lowrail::ARShadow.instantiate(self, plan.builder) if ::Lowrail::ARShadow.enabled?
                    attributes = plan.builder.build_from_database(record, column_types)
                    object = allocate.init_with_attributes(attributes, &block)
                    ::Lowrail::ARInstantiate.count(#{id}, true)
                    object
                  else
                    ::Lowrail::ARInstantiate.count(#{id}, false)
                    instantiate_instance_of(self, record, column_types, &block)
                  end
                end
              end
            end
          end
        RUBY
      end

      def count(id, hit)
        Stats.count(id, hit) if defined?(Stats) && Stats.enabled?
      end
    end

    class Entry
      attr_reader :klass, :id

      def initialize(klass, unit)
        @klass, @unit = klass, unit
        @id = unit.fetch("id")
        @builder = @epoch = nil
      end

      # Do not force schema/type initialization at activation. The first
      # lookup occurs at Rails' original first-row position, after notification
      # start and STI discrimination, and only after method facts validate.
      def builder
        @builder ||= @klass.attributes_builder.tap { @epoch = AR.epoch(@klass) }
      end

      def current?
        Guard.state[@id] == true && (!@epoch || AR.epoch(@klass) == @epoch)
      end

      def valid?
        return false if @epoch && AR.epoch(@klass) != @epoch
        state = Guard.state
        return state[@id] unless state[@id].nil?
        original = @klass.method(:_load_from_sql).super_method
        original = original.super_method while original&.source_location&.first&.start_with?("lowrail:ar_instantiate:")
        state[@id] = Guard.validate(@id) && ARInstantiate.original_fact(original) == @unit.fetch("ar_instantiate").fetch("original")
      rescue StandardError
        false
      end
    end
  end

  module Passes
    ARInstantiate = Lowrail::ARInstantiate
  end
end
