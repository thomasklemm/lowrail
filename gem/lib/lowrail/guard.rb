# frozen_string_literal: true

module Lowrail
  # Validates the boot facts a unit assumed and resets units when a method
  # they depend on may have changed. Resetting sets the state back to nil, so
  # the next call revalidates: a stubbed method falls back to the original
  # body, and the fast path returns once the stub is removed.
  module Guard
    class << self
      attr_reader :manifest

      def install(manifest)
        @manifest = manifest
        @units = manifest.units.to_h { |u| [u.fetch("id"), u] }
        Module.prepend(ModuleHooks) unless Module < ModuleHooks
        BasicObject.prepend(ObjectHooks) unless BasicObject < ObjectHooks
      end

      def validate(id)
        unit = @units[id] or return false
        unit.fetch("facts").all? { |fact| holds?(fact) }
      rescue StandardError
        false
      end

      def reset_method(name)
        ids = @manifest&.units_by_method&.fetch(name.to_s, nil) or return
        ids.each { |id| G[id] = nil }
      end

      def reset_all
        G.fill(nil)
      end

      private

      # A method fact: Receiver#method resolves to owner, defined at
      # source_location, with the given visibility.
      def holds?(fact)
        mod = Object.const_get(fact.fetch("receiver"))
        name = fact.fetch("method").to_sym
        meth = fact["singleton"] ? mod.singleton_class.instance_method(name) : mod.instance_method(name)
        return false unless meth.owner.name == fact.fetch("owner") || (fact["singleton"] && meth.owner == mod.singleton_class)
        return false unless meth.source_location&.join(":") == fact["source_location"]
        visibility_of(fact["singleton"] ? mod.singleton_class : mod, name) == fact.fetch("visibility")
      rescue NameError
        false
      end

      def visibility_of(mod, name)
        if mod.public_method_defined?(name) then "public"
        elsif mod.protected_method_defined?(name) then "protected"
        else "private"
        end
      end
    end

    module ModuleHooks
      private

      def method_added(name) = (Guard.reset_method(name); super)
      def method_removed(name) = (Guard.reset_method(name); super)
      def method_undefined(name) = (Guard.reset_method(name); super)
      def append_features(base) = (Guard.reset_all; super)
      def prepend_features(base) = (Guard.reset_all; super)
      def extend_object(obj) = (Guard.reset_all; super)
    end

    module ObjectHooks
      private

      def singleton_method_added(name) = (Lowrail::Guard.reset_method(name); super)
      def singleton_method_removed(name) = (Lowrail::Guard.reset_method(name); super)
      def singleton_method_undefined(name) = (Lowrail::Guard.reset_method(name); super)
    end
  end
end
