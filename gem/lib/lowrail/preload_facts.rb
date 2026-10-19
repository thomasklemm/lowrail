# frozen_string_literal: true

module Lowrail
  # The inputs to a preload plan, not rows or query results. Shared by the
  # booted build helper and the runtime; deliberately separate from app facts.
  module PreloadFacts
    SCOPE_METHODS = %i[scope_for_association relation default_scoped build_default_scope
      unscoped arel_table predicate_builder polymorphic_name table_name primary_key].freeze
    RELATION_METHODS = %i[initialize initialize_copy spawn where where! merge! values_for_queries].freeze
    module_function

    def model(klass)
      { "table" => klass.table_name, "primary_key" => klass.primary_key,
        "connection" => klass.connection_specification_name,
        "polymorphic_name" => klass.polymorphic_name,
        "inheritance_column" => klass.inheritance_column,
        "columns" => klass.columns_hash.map { |name, c|
          [name, c.sql_type, c.type.to_s, c.limit, c.precision, c.scale, c.null,
           klass.type_for_attribute(name).class.name]
        }.sort }
    end

    def reflection(r)
      { "owner" => r.active_record.name, "name" => r.name.to_s,
        "macro" => r.macro.to_s, "target" => r.klass.name,
        "options" => value(r.options), "scope" => scope(r)&.source_location,
        "scope_name" => scope_name(r),
        "foreign_key" => r.join_foreign_key, "primary_key" => r.join_primary_key }
    end

    def value(v)
      case v
      when Hash then v.to_h { |k, x| [k.to_s, value(x)] }
      when Array then v.map { value(_1) }
      when Symbol then v.to_s
      when Proc then ["proc", v.source_location]
      when Module then ["constant", v.name]
      when String, Numeric, true, false, nil then v
      else raise ArgumentError, "non-literal reflection option: #{v.class}"
      end
    end

    def scope(r)
      s = r.scope
      if s && s.source_location&.first&.end_with?("/associations/builder/association.rb")
        s = s.binding.local_variable_get(:scope)
      end
      s
    end

    def scope_name(r)
      s = scope(r)
      s && s.binding.local_variable_defined?(:name) ? value(s.binding.local_variable_get(:name)) : nil
    end

    # Certify precisely Rails' generated `where(name: name)` closures, not
    # arbitrary code merely living in a framework directory. App lambdas,
    # including zero-arity Current/time-dependent scopes, remain on Rails.
    def certified_scope?(r)
      return true unless r.scope
      s = scope(r)
      path, line = s.source_location
      paths = %w[activestorage/lib/active_storage/attached/model.rb actiontext/lib/action_text/attribute.rb]
      return false unless paths.any? { path.end_with?("/#{_1}") }
      return false unless File.readlines(path)[line - 1]&.match?(/\A\s*has_(?:one|many) :".*", -> \{ where\(name: name\) \},/)
      String === scope_name(r) || Symbol === s.binding.local_variable_get(:name)
    end

    def decline(r)
      return "missing reflection" unless r
      return "through association" if r.options[:through]
      return "polymorphic belongs_to" if r.polymorphic?
      return "owner-dependent scope" if r.scope && r.scope.arity != 0
      return "non-certified scope" unless certified_scope?(r)
      return "composite key" if Array === r.join_primary_key || Array === r.join_foreign_key
      k = r.klass
      return "abstract target" if k.abstract_class?
      return "default scope" unless k.default_scopes.empty?
      # An app can override these constructors to inject request state without
      # declaring any association/default scope. Such code is not certified.
      framework = Gem.loaded_specs.fetch("activerecord").full_gem_path + "/"
      return "custom reflection scope constructor" unless r.method(:join_scopes).source_location&.first&.start_with?(framework)
      return "custom scope constructor" unless SCOPE_METHODS.all? { |name|
        k.method(name).source_location&.first&.start_with?(framework)
      }
      return "custom relation constructor" unless RELATION_METHODS.all? { |name|
        k.unscoped.class.instance_method(name).source_location&.first&.start_with?(framework)
      }
      # STI can introduce a different target/reflection partway through a tree.
      return "STI target" if k.columns_hash.key?(k.inheritance_column)
      return "deprecated association" if r.options[:deprecated]
      nil
    end

    def method_fact(mod, name, singleton: false)
      holder = singleton ? mod.singleton_class : mod
      m = holder.instance_method(name)
      { "receiver" => mod.name, "method" => name.to_s, "singleton" => singleton, "exact" => true,
        "owner" => m.owner.name || "#<Class:#{mod.name}>",
        "source_location" => m.source_location&.join(":"),
        "visibility" => holder.public_method_defined?(name) ? "public" : (holder.protected_method_defined?(name) ? "protected" : "private") }
    end
  end
end
