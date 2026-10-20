# frozen_string_literal: true

module Lowrail
  # State of the certified destination, not of the module passed to include.
  # Kept only by seal-check. UnboundMethod equality catches same-location edits
  # that owner/source_location alone would miss; getters do not dispatch to app
  # overrides and autoloads are described without loading them.
  module SealSnapshot
    NAME = Module.instance_method(:name)
    ANCESTORS = Module.instance_method(:ancestors)
    PUBLIC = Module.instance_method(:public_instance_methods)
    PROTECTED = Module.instance_method(:protected_instance_methods)
    PRIVATE = Module.instance_method(:private_instance_methods)
    METHOD = Module.instance_method(:instance_method)
    CONSTANTS = Module.instance_method(:constants)
    DEFINED = Module.instance_method(:const_defined?)
    AUTOLOAD = Module.instance_method(:autoload?)
    CONSTANT = Module.instance_method(:const_get)
    CONSTANT_SOURCE = Module.instance_method(:const_source_location)
    EQUAL = UnboundMethod.instance_method(:==)
    IDENTITY = BasicObject.instance_method(:equal?)

    def self.capture(holder)
      methods = {}
      {"public" => PUBLIC, "protected" => PROTECTED, "private" => PRIVATE}.each do |visibility, getter|
        getter.bind_call(holder, false).each { |name| methods[name] = [visibility, METHOD.bind_call(holder, name)] }
      end
      constants = CONSTANTS.bind_call(holder, false).filter_map do |name|
        # Rails::Application::Railties leaves an enumerated but undefined
        # autoload slot after Rails eager loading; do not invoke const_missing.
        next unless DEFINED.bind_call(holder, name, false)
        path = AUTOLOAD.bind_call(holder, name, false)
        [name, path ? [:autoload, path.dup.freeze] : [:value, CONSTANT.bind_call(holder, name, false), CONSTANT_SOURCE.bind_call(holder, name, false)]]
      end.to_h
      {ancestors: ANCESTORS.bind_call(holder), methods: methods, constants: constants}
    end

    def self.method_description(entry)
      return unless entry
      visibility, method = entry
      {"visibility" => visibility, "owner" => NAME.bind_call(method.owner), "source_location" => method.source_location}
    end

    def self.diff(before, after)
      changes = {}
      old, current = before.fetch(:ancestors), after.fetch(:ancestors)
      unless old.size == current.size && old.zip(current).all? { |a, b| IDENTITY.bind_call(a, b) }
        changes["ancestors"] = [old, current].map { |list| list.map { NAME.bind_call(_1) || "<anonymous>" } }
      end
      old, current = before.fetch(:methods), after.fetch(:methods)
      methods = (old.keys | current.keys).filter_map do |name|
        a, b = old[name], current[name]
        next if a && b && a[0] == b[0] && EQUAL.bind_call(a[1], b[1])
        {"name" => name.to_s, "before" => method_description(a), "after" => method_description(b)}
      end
      changes["methods"] = methods unless methods.empty?
      old, current = before.fetch(:constants), after.fetch(:constants)
      constants = (old.keys | current.keys).reject do |name|
        a, b = old[name], current[name]
        a && b && a[0] == b[0] && (a[0] == :autoload ? a[1] == b[1] : IDENTITY.bind_call(a[1], b[1]))
      end
      changes["constant_bindings_or_autoloads"] = constants.map(&:to_s) unless constants.empty?
      unless constants.empty?
        changes["constant_sources"] = constants.map do |name|
          a, b = old[name], current[name]
          {"name" => name.to_s, "before_kind" => a&.first&.to_s, "after_kind" => b&.first&.to_s,
            "before_source" => a && (a[0] == :autoload ? [a[1], 0] : a[2]),
            "after_source" => b && (b[0] == :autoload ? [b[1], 0] : b[2])}
        end
      end
      changes
    end
  end
end
