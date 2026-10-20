# frozen_string_literal: true

# A source inventory, NOT certification or a lowering pass. No app writes.
# Each syntactic query primitive is counted separately.
require "prism"
require "json"

class Lowrail::ARPlanSites < Prism::Visitor
  METHODS = %i[where find_by find_by! order limit select includes preload].freeze
  attr_reader :ledger

  def initialize(file)
    @file = file
    @ledger = []
  end

  def visit_call_node(node)
    if METHODS.include?(node.name)
      receiver = node.receiver
      kind = case receiver
      when nil then "implicit scope/model"
      when Prism::ConstantReadNode, Prism::ConstantPathNode then "constant"
      else "association/scoped/dynamic"
      end
      args = node.arguments&.arguments || []
      shape = if node.block
        "block (query/enumerable distinction unresolved)"
      elsif node.name == :where && args.empty?
        "WhereChain (not/missing/associated)"
      elsif %i[where find_by find_by!].include?(node.name)
        hash = args.first
        if args.size != 1 || ![Prism::KeywordHashNode, Prism::HashNode].include?(hash.class)
          "SQL fragment or dynamic argument hash"
        elsif !hash.elements.all? { _1.is_a?(Prism::AssocNode) && _1.key.is_a?(Prism::SymbolNode) }
          "nonconstant/nested keys or splat"
        elsif hash.elements.any? { [Prism::ArrayNode, Prism::RangeNode, Prism::HashNode].include?(_1.value.class) }
          "array/range/nested predicate"
        else
          "fixed hash keys (runtime value/type checks needed)"
        end
      elsif args.all? { literal?(_1) }
        "literal #{node.name} arguments"
      else
        "dynamic #{node.name} arguments"
      end
      reason = if kind == "constant" && %i[find_by find_by!].include?(node.name)
        "existing Rails StatementCache candidate; no new planning win"
      elsif shape.start_with?("fixed hash", "literal")
        "not certified: #{kind}; lazy/scoping/metadata contract unproven"
      else
        "refused: #{shape}"
      end
      @ledger << { file: @file, line: node.location.start_line, pass: "active_record/ar_plans_survey",
        helper: node.name, receiver: kind, shape: shape, outcome: reason }
    end
    super
  end

  def literal?(node)
    return true if [Prism::SymbolNode, Prism::StringNode, Prism::IntegerNode, Prism::NilNode, Prism::TrueNode, Prism::FalseNode].include?(node.class)
    return node.elements.all? { literal?(_1) } if node.is_a?(Prism::ArrayNode)
    return node.elements.all? { _1.is_a?(Prism::AssocNode) && literal?(_1.key) && literal?(_1.value) } if [Prism::HashNode, Prism::KeywordHashNode].include?(node.class)
    false
  end

  def self.inventory(app)
    Dir[File.join(app, "app/**/*.rb")].sort.reject { _1.match?(%r{/app/(assets|javascript)/}) }.flat_map do |file|
      result = Prism.parse_file(file)
      abort "cannot survey #{file}: #{result.errors.inspect}" unless result.success?
      visitor = new(file)
      visitor.visit(result.value)
      visitor.ledger.map { _1.merge(app: File.basename(app)) }
    end
  end
end
