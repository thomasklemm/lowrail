# ruby docs_probe.rb TREE...: what RDoc and YARD document for Rack::Utils.unescape.
require "rdoc/rdoc"
require "yard"
ARGV.each do |tree|
  r = RDoc::RDoc.new
  r.document(["--quiet", "--dry-run", "--op", "/tmp/rdoc-probe-#{File.basename(tree)}", *Dir["#{tree}/lib/**/*.rb"]])
  rd = r.store.find_class_or_module("Rack::Utils").method_list.select { |m| m.name == "unescape" }
    .map { |m| { singleton: m.singleton, params: m.params, call_seq: m.call_seq, doc: m.comment.to_s } }
  YARD::Registry.clear
  YARD.parse(Dir["#{tree}/lib/**/*.rb"])
  yd = %w[Rack::Utils.unescape Rack::Utils#unescape].map { |p| o = YARD::Registry.at(p); o && { path: p, vis: o.visibility, params: o.parameters, doc: o.docstring.to_s } }.compact
  p tree: File.basename(tree), rdoc: rd, yard: yd
end
