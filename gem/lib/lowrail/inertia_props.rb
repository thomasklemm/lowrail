# frozen_string_literal: true

module Lowrail
  module Passes
    # Only iteration is specialized. The gem's body, lexical scope, dispatch,
    # recursion and original each_with_object branch stay in the source ISeq.
    module InertiaProps
      PASS = "inertia/props"
      HASH = ::Hash
      CLASS = Kernel.instance_method(:class)
      SINGLETON_CLASS = Kernel.instance_method(:singleton_class)
      INSTANCE_METHOD = Module.instance_method(:instance_method)
      PUBLIC = Module.instance_method(:public_method_defined?)
      EACH = Hash.instance_method(:each)
      EACH_WITH_OBJECT = Enumerable.instance_method(:each_with_object)

      class << self
        def install(units)
          @units = units
          @active = {}
        end

        def activate
          return unless EACH.owner.equal?(HASH) && EACH.source_location.nil? && EACH.original_name == :each &&
            EACH_WITH_OBJECT.owner.equal?(Enumerable) && EACH_WITH_OBJECT.source_location.nil? &&
            EACH_WITH_OBJECT.original_name == :each_with_object
          @units.each do |unit|
            @active[unit.fetch("id")] = unit.fetch("data").fetch("sources").all? do |path, sha|
              File.file?(path) && Manifest.sha256_file(path) == sha
            end
          end
        rescue StandardError, ScriptError => e
          @active = {}
          Lowrail.debug("Inertia props declined: #{e.class}: #{e.message}")
        end

        def active?(id) = @active && @active[id]

        def valid?(id, props)
          return false unless ::Ractor.current.equal?(::Ractor.main)
          ok = active?(id) &&
            (Guard.state[id] || (Guard.state[id] = Guard.validate(id))) && CLASS.bind_call(props).equal?(HASH)
          if ok
            holder = SINGLETON_CLASS.bind_call(props)
            # Never trust the invalidation cache for actual receiver dispatch:
            # hooks can be suppressed and visibility changes fire no hook.
            ok = PUBLIC.bind_call(holder, :each_with_object) && PUBLIC.bind_call(holder, :each) &&
              INSTANCE_METHOD.bind_call(holder, :each_with_object) == EACH_WITH_OBJECT &&
              INSTANCE_METHOD.bind_call(holder, :each) == EACH
          end
          Stats.count(id, !!ok) if defined?(Stats) && Stats.enabled?
          ok
        rescue TypeError, NameError
          false
        end
      end
    end
  end
end
