# frozen_string_literal: true

# Splits ZJIT's send_fallback_send_block_arg_not_nil per ISEQ by what the call sites in that ISEQ pass as `&arg`
# (docs/upstream/zjit-yjit-gap.md, Symbol block arguments):
#   ruby SCRIPT ZJIT_STATS.json [N]   (needs the prism gem; any Ruby with Prism works, e.g. 4.0.9)
# Each ISEQ key is label@path:first_lineno. The script parses path, finds the def or block that starts on that line
# and collects the block-argument calls that belong to that ISEQ itself (nested blocks and defs are their own ISEQs):
#   symbol    foo(&:sym)
#   forward   foo(&block) of a block parameter (of this scope or an enclosing def or block), or foo(&)
#   other     anything else (a local, a method call, a constant)
# An ISEQ whose calls are all of one kind gets that kind; one with several kinds is "mixed", listed with its calls.
require "json"
require "prism"

stats_path, n = ARGV
n = Integer(n || 25)
COUNTER = "send_fallback_send_block_arg_not_nil"

per_iseq = Hash.new(0)
JSON.parse(File.read(stats_path))["per_itr"].each do |key, v|
  next unless key.start_with?("iseq:#{COUNTER}:")
  per_iseq[key.delete_prefix("iseq:#{COUNTER}:")] += v
end

class BlockArgCalls < Prism::Visitor
  attr_reader :calls

  def initialize(block_params)
    @block_params = block_params
    @calls = []
  end

  # Nested scopes compile to their own ISEQs.
  def visit_def_node(_) = nil
  def visit_block_node(_) = nil
  def visit_lambda_node(_) = nil

  def visit_call_node(node) = record(node) && super
  def visit_super_node(node) = record(node) && super

  def record(node)
    arg = node.block
    if arg.is_a?(Prism::BlockArgumentNode)
      expr = arg.expression
      kind = case expr
             when Prism::SymbolNode then "symbol"
             when nil then "forward"
             when Prism::LocalVariableReadNode then @block_params.include?(expr.name) ? "forward" : "other"
             else "other"
             end
      name = node.is_a?(Prism::CallNode) ? node.name : :super
      @calls << [kind, "#{name}(&#{expr ? expr.slice : ""}) line #{node.location.start_line}"]
    end
    true
  end
end

# ISEQ keys carry the line of the first instruction, not of the def or block, so the scope is the def named like the
# label that contains the line, or the block at the label's nesting depth inside it that contains the line.
def scope_at(path, line, label)
  return nil unless File.exist?(path) && path.end_with?(".rb")
  m = label.match(/\Ablock (?:\((\d+) levels\) )?in (.+)\z/)
  depth = m ? Integer(m[1] || 1) : 0
  name = (m ? m[2] : label).split(/[#.]/).last.to_sym
  contains = ->(node) { node.location.start_line <= line && line <= node.location.end_line }
  best = nil
  best_outer = []
  block_param = lambda do |node|
    params = node.respond_to?(:parameters) && node.parameters
    params = params.parameters if params.is_a?(Prism::BlockParametersNode)
    params.respond_to?(:block) ? params.block&.name : nil
  end
  outer = []
  walk = lambda do |node, in_def, level|
    return if node.nil?
    if node.is_a?(Prism::DefNode)
      return unless contains.(node)
      if node.name == name
        if depth.zero? && (best.nil? || node.location.start_line >= best.location.start_line)
          best = node
          best_outer = outer.dup
        end
        outer.push(block_param.(node))
        node.compact_child_nodes.each { walk.(_1, true, 0) }
        outer.pop
        return
      end
      node.compact_child_nodes.each { walk.(_1, in_def, level) }
      return
    end
    if in_def && (node.is_a?(Prism::BlockNode) || node.is_a?(Prism::LambdaNode))
      level += 1
      if level == depth && contains.(node) && (best.nil? || node.location.start_line >= best.location.start_line)
        best = node
        best_outer = outer.dup
      end
      outer.push(block_param.(node))
      node.compact_child_nodes.each { walk.(_1, in_def, level) }
      outer.pop
      return
    end
    node.compact_child_nodes.each { walk.(_1, in_def, level) }
  end
  walk.(Prism.parse_file(path).value, false, 0)
  best && [best, best_outer.compact]
end

def classify(iseq)
  m = iseq.match(/\A(.*)@(.*):(\d+)\z/) or return ["unknown", []]
  label, path, line = m[1], m[2], Integer(m[3])
  scope, outer = scope_at(path, line, label) || (return ["unknown", []])
  params = scope.respond_to?(:parameters) && scope.parameters
  params = params.parameters if params.is_a?(Prism::BlockParametersNode)
  block_params = [*(params.respond_to?(:block) ? params.block&.name : nil), *outer].compact
  visitor = BlockArgCalls.new(block_params)
  body = scope.body
  body&.accept(visitor)
  kinds = visitor.calls.map(&:first).uniq
  [kinds.size == 1 ? kinds.first : (kinds.empty? ? "none found" : "mixed"), visitor.calls]
end

rows = per_iseq.map { |iseq, v| [iseq, v, *classify(iseq)] }
totals = rows.each_with_object(Hash.new(0)) { |(_, v, kind, _), h| h[kind] += v }
puts "#{COUNTER} per iteration: #{per_iseq.values.sum.round} (#{totals.sort_by { -_2 }.map { |k, v| "#{k} #{v.round}" }.join(", ")})"
puts
puts "| ISEQ | per iteration | kind | block-argument calls in the ISEQ |"
puts "|---|---:|---|---|"
rows.sort_by { -_2 }.first(n).each do |iseq, v, kind, calls|
  short = iseq.sub(%r{\A(.*?@).*/gems/}, '\1').sub(%r{\A(.*?@).*/lib/ruby/[^/]+/}, '\1').sub(%r{\A(.*?@)/home/user/w/rbc/[^/]+/}, '\1')
  puts "| `#{short}` | #{v.round} | #{kind} | #{calls.map { "`#{_2}`" }.uniq.join(", ")} |"
end
