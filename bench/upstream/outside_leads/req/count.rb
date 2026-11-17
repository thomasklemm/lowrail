# ruby count.rb APP  (inside copy via countrun.rb): calls per op for selected methods
require_relative "../../census/harness"
app = ARGV[0]
RailsCensus.boot(app)
C = Hash.new(0)
def wrap(mod, meth, label, singleton: false)
  target = singleton ? mod.singleton_class : mod
  return unless target.method_defined?(meth) || target.private_method_defined?(meth)
  m = Module.new { define_method(meth) { |*a, **k, &b| C[label] += 1; super(*a, **k, &b) } }
  target.prepend(m)
end
wrap(Rack::Utils, :unescape, "Rack::Utils.unescape", singleton: true)
wrap(Rack::Utils, :escape, "Rack::Utils.escape", singleton: true)
wrap(Rack::QueryParser, :unescape, "QueryParser#unescape")
if defined?(Nokogiri)
  wrap(Nokogiri::XML::Node, :css, "Node#css"); wrap(Nokogiri::XML::NodeSet, :css, "NodeSet#css")
  wrap(Nokogiri::XML::DocumentFragment, :css, "DocumentFragment#css"); wrap(Nokogiri::XML::Node, :xpath, "Node#xpath")
  wrap(Nokogiri::XML::Document, :dup, "Document#dup"); wrap(Nokogiri::CSS, :xpath_for, "CSS.xpath_for", singleton: true)
  wrap(Nokogiri::XML::XPathContext, :evaluate, "XPathContext#evaluate")
end
wrap(CanCan::Ability, :can?, "CanCan#can?") if defined?(CanCan)
wrap(URI::RFC3986_Parser, :split, "URI split") 
ops = RailsCensus.workloads(app)
ops.each do |op|
  20.times { op.call.call; RailsCensus.reset_side_effects }
  C.clear
  10.times { c = op.call; c.call; RailsCensus.reset_side_effects }
  puts "#{app} | #{op.name} | " + C.sort.map { |k, v| "#{k}=#{v / 10.0}" }.join(" ")
end
