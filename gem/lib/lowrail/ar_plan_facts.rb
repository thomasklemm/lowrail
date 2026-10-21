# frozen_string_literal: true

require_relative "preload_facts"

module Lowrail
  module ARPlanFacts
    module_function

    def scope_info(reflection)
      scope = PreloadFacts.scope(reflection)
      return [nil, "no scope (Rails already caches this reader)"] unless scope
      return [nil, "owner-dependent scope"] unless scope.arity.zero?
      if PreloadFacts.certified_scope?(reflection)
        return [{ "generated_name" => PreloadFacts.scope_name(reflection), "columns" => ["name"] }, nil]
      end
      require_relative "prism_grammar"
      file, line = scope.source_location
      return [nil, "scope source unavailable"] unless file && File.file?(file)
      parsed = Prism.parse_file(file, version: PrismGrammar.version)
      return [nil, "scope source does not parse"] unless parsed.success?
      nodes = []
      visit = lambda do |node|
        nodes << node if node.is_a?(Prism::LambdaNode) && node.location.start_line == line
        node.compact_child_nodes.each { visit.call(_1) }
      end
      visit.call(parsed.value)
      return [nil, "scope lambda is not uniquely located"] unless nodes.size == 1
      node = nodes.first
      return [nil, "scope parameters"] if node.parameters
      body = node.body
      return [nil, "scope is not one fixed query chain"] unless body.is_a?(Prism::StatementsNode) && body.body.size == 1
      columns = []
      return [nil, "scope contains dynamic values or unsupported operations"] unless fixed_chain?(body.body.first, columns)
      [{ "columns" => columns.uniq, "source" => Digest::SHA256.file(file).hexdigest }, nil]
    end

    def fixed_chain?(node, columns)
      return false unless node.is_a?(Prism::CallNode) && !node.block
      return false unless %i[where order limit select includes preload].include?(node.name)
      return false if node.receiver && !node.receiver.is_a?(Prism::SelfNode) && !fixed_chain?(node.receiver, columns)
      args = node.arguments&.arguments || []
      return false if args.empty?
      if node.name == :where
        hash = args.first
        return false unless args.size == 1 && [Prism::KeywordHashNode, Prism::HashNode].include?(hash.class)
        return false unless hash.elements.all? { _1.is_a?(Prism::AssocNode) && _1.key.is_a?(Prism::SymbolNode) && scalar?(_1.value) }
        columns.concat(hash.elements.map { _1.key.unescaped })
        true
      elsif node.name == :limit
        args.size == 1 && args.first.is_a?(Prism::IntegerNode)
      else
        args.all? { literal?(_1) }
      end
    end

    def scalar?(node)
      [Prism::SymbolNode, Prism::StringNode, Prism::IntegerNode, Prism::NilNode, Prism::TrueNode, Prism::FalseNode].include?(node.class)
    end

    def literal?(node)
      return true if scalar?(node)
      return node.elements.all? { literal?(_1) } if node.is_a?(Prism::ArrayNode)
      return node.elements.all? { _1.is_a?(Prism::AssocNode) && literal?(_1.key) && literal?(_1.value) } if [Prism::HashNode, Prism::KeywordHashNode].include?(node.class)
      false
    end

    def bind_columns(reflection, info)
      (info.fetch("columns") + [reflection.join_primary_key, reflection.type].compact).uniq
    end

    def decline(reflection, info)
      return "through association" if reflection.options[:through]
      return "polymorphic belongs_to" if reflection.polymorphic?
      return "association extensions" unless reflection.extensions.empty?
      return "composite key" if Array === reflection.join_primary_key || Array === reflection.join_foreign_key
      owner, target = reflection.active_record, reflection.klass
      return "default scope" unless owner.default_scopes.empty? && target.default_scopes.empty?
      return "STI target" if target.columns_hash.key?(target.inheritance_column)
      framework = %w[activerecord activemodel].map { Gem.loaded_specs.fetch(_1).full_gem_path + "/" }
      return "custom owner attribute reader" unless owner.instance_method(:_read_attribute).source_location&.first&.start_with?(*framework)
      return "custom scope constructor" unless PreloadFacts::SCOPE_METHODS.all? { target.method(_1).source_location&.first&.start_with?(*framework) }
      return "custom reflection constructor" unless PreloadFacts::REFLECTION_METHODS.all? { reflection.method(_1).source_location&.first&.start_with?(*framework) }
      return "custom relation constructor" unless PreloadFacts::RELATION_METHODS.all? { target.unscoped.class.instance_method(_1).source_location&.first&.start_with?(*framework) }
      return "unknown scope column or alias" unless bind_columns(reflection, info).all? { target.columns_hash.key?(_1) && !target.attribute_aliases.key?(_1) }
      return "custom or enum scope type" unless bind_columns(reflection, info).all? { |column|
        type = target.type_for_attribute(column)
        %w[ActiveModel::Type::String ActiveModel::Type::ImmutableString ActiveRecord::Type::Text
          ActiveRecord::ConnectionAdapters::SQLite3Adapter::SQLite3Integer ActiveModel::Type::Integer
          ActiveModel::Type::Boolean].include?(type.class.name) && type.singleton_methods.empty? &&
          PreloadFacts.type_methods(type.class).values.flatten(1).all? { _1&.first&.start_with?(*framework) }
      }
      nil
    end
  end
end
