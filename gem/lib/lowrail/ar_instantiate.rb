# frozen_string_literal: true

module Lowrail
  # One ordinary singleton-class def (and ISeq) per model. Rails still owns
  # object initialization, lazy casting, callbacks and instrumentation.
  module ARInstantiate
    PASS = "active_record/instantiate"

    class << self
      def install(manifest)
        require_relative "ar_guard"
        AR.install
        @units = manifest.units.select { _1["pass"] == PASS }
        if defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load)
          ActiveSupport.on_load(:after_initialize) { Lowrail::ARInstantiate.activate }
        else
          @boot = TracePoint.new(:end) do |event|
            if event.self.is_a?(Class) && event.self.name == "Rails::Application"
              @boot.disable
              ActiveSupport.on_load(:after_initialize) { Lowrail::ARInstantiate.activate }
            end
          end
          @boot.enable
        end
      end

      def activate
        require_relative "ar_guard"
        require "digest"
        entries = @units.filter_map do |unit|
          data = unit.fetch("ar_instantiate")
          next unless Rails.version == data.fetch("rails_version")
          next unless data.fetch("sources").all? { |p, sha| File.file?(p) && Digest::SHA256.file(p).hexdigest == sha }
          klass = Object.const_get(data.fetch("model"))
          next unless original_fact(klass.method(:_load_from_sql)) == data.fetch("original")
          klass.define_attribute_methods
          Entry.new(klass, unit)
        rescue StandardError, ScriptError => e
          Lowrail.debug("AR instantiate declined: #{e.class}: #{e.message}")
          nil
        end
        entries.each do |entry|
          klass = entry.klass
          klass.instance_variable_set(:@_lowrail_instantiate, entry)
          klass.singleton_class.class_eval(source(entry.id), "lowrail:ar_instantiate:#{klass.name}", 1)
        rescue StandardError, ScriptError => e
          Lowrail.debug("AR instantiate installation declined: #{e.class}: #{e.message}")
        end
      rescue LoadError => e
        Lowrail.debug("AR instantiate unavailable: #{e.message}")
      end

      def original_fact(method)
        { "owner" => method.owner.name || method.owner.to_s,
          "source_location" => method.source_location }
      end

      def source(id)
        <<~RUBY
          def _load_from_sql(result_set, &block)
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
      attr_reader :klass, :builder, :id

      def initialize(klass, unit)
        @klass, @unit = klass, unit
        @id = unit.fetch("id")
        @builder = klass.attributes_builder
        @epoch = AR.epoch(klass)
      end

      def current?
        Guard.state[@id] == true && AR.epoch(@klass) == @epoch
      end

      def valid?
        return false unless AR.epoch(@klass) == @epoch
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
end
