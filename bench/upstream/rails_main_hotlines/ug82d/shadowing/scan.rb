# Static scan: class-level method definitions whose name a relation answers itself.
# Usage: ruby scan.rb NAMES_FILE NEW_NAMES_FILE APP_DIR...
require "prism"
require "json"

names = File.readlines(ARGV.shift, chomp: true).to_h { [_1.to_sym, true] }
new_names = File.readlines(ARGV.shift, chomp: true).map(&:to_sym)

class Finder < Prism::Visitor
  attr_reader :hits

  def initialize(path, names, extended)
    @path, @names, @hits, @stack, @singleton, @extended = path, names, [], [], 0, extended
    @class_methods = 0
  end

  def visit_class_node(node)
    sup = node.superclass&.slice
    @stack.push([node.constant_path.slice, sup])
    super
    @stack.pop
  end

  def visit_module_node(node)
    name = node.constant_path.slice
    @stack.push([name, nil])
    @class_methods += 1 if name == "ClassMethods"
    super
    @class_methods -= 1 if name == "ClassMethods"
    @stack.pop
  end

  def visit_singleton_class_node(node)
    @singleton += 1
    super
    @singleton -= 1
  end

  def visit_call_node(node)
    if node.name == :class_methods && node.block
      @class_methods += 1
      super
      @class_methods -= 1
    elsif node.name == :define_singleton_method && (arg = node.arguments&.arguments&.first).is_a?(Prism::SymbolNode)
      record(arg.unescaped.to_sym, node, "define_singleton_method")
      super
    else
      super
    end
  end

  def visit_def_node(node)
    kind =
      if node.receiver.is_a?(Prism::SelfNode) then "def self."
      elsif node.receiver.nil? && @singleton > 0 then "class << self"
      elsif node.receiver.nil? && @class_methods > 0 then "ClassMethods"
      elsif node.receiver.nil? && @stack.last && @stack.last[1].nil? && @extended.include?(@stack.last[0].split("::").last) then "extended module"
      end
    record(node.name, node, kind) if kind
    super
  end

  def record(name, node, kind)
    return unless @names[name]
    params = node.respond_to?(:parameters) && node.parameters ? node.parameters.slice : ""
    @hits << { file: @path, line: node.location.start_line, name: name, kind: kind, params: params,
               scope: @stack.map(&:first).join("::"), superclass: @stack.reverse.find { _1[1] }&.last }
  end
end

# Relation forwards these to the model itself (Delegation), so they are not shadowed.
FORWARDED = %i[primary_key with_connection connection table_name transaction sanitize_sql_like unscoped name]

class SuperFinder < Prism::Visitor
  attr_reader :supers, :extends
  def initialize(supers, extends) = (@supers, @extends, @cls = supers, extends, [])
  def visit_class_node(node)
    @supers[node.constant_path.slice.split("::").last] ||= node.superclass&.slice&.delete_prefix("::")
    @cls.push(node.constant_path.slice)
    super
    @cls.pop
  end
  def visit_call_node(node)
    if node.name == :extend && node.receiver.nil? && @cls.any?
      node.arguments&.arguments&.each { |a| (@extends[a.slice.split("::").last] ||= []) << @cls.last if a.is_a?(Prism::ConstantReadNode) || a.is_a?(Prism::ConstantPathNode) }
    end
    super
  end
end

def model?(name, supers, seen = {})
  return false if name.nil? || seen[name]
  seen[name] = true
  return true if %w[ActiveRecord::Base ApplicationRecord].include?(name)
  model?(supers[name.split("::").last], supers, seen)
end

all = []
ARGV.each do |dir|
  files = Dir.glob("{app,lib,plugins,engines,packs,enterprise,components}/**/*.rb", base: dir).reject { _1.match?(%r{(^|/)(spec|test|vendor|node_modules|db)/}) }
  parsed = files.to_h { [_1, Prism.parse_file(File.join(dir, _1)).value] }
  supers, extends = {}, {}
  parsed.each_value { _1.accept(SuperFinder.new(supers, extends)) }
  extended = extends.select { |_, classes| classes.any? { model?(_1, supers) } }.keys
  app = File.basename(dir)
  parsed.each do |rel, tree|
    f = Finder.new(rel, names, extended)
    tree.accept(f)
    f.hits.each do |h|
      next if FORWARDED.include?(h[:name])
      owner = h[:scope].split("::").reject { _1 == "ClassMethods" }.last
      where =
        if model?(h[:superclass], supers) || model?(owner, supers) then "model"
        elsif h[:kind] == "extended module" then "extended into a model"
        elsif h[:kind] != "def self." && h[:superclass].nil? && rel.match?(%r{models/|concerns/}) then "model concern"
        end
      all << h.merge(app: app, where: where, new_on_main: new_names.include?(h[:name])) if where
    end
  end
end
puts JSON.pretty_generate(all)
