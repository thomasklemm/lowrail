# ruby docs_all.rb TREE: every RDoc and YARD entry under Rack (name, params, doc), for diffing two trees.
require "rdoc/rdoc"; require "yard"
tree = ARGV[0]
r = RDoc::RDoc.new
r.document(["--quiet", "--dry-run", "--op", "/tmp/rdoc-all", *Dir["#{tree}/lib/**/*.rb"]])
r.store.all_classes_and_modules.sort_by(&:full_name).each do |c|
  (c.method_list + c.attributes).sort_by { |m| [m.name, m.singleton ? 1 : 0] }.each { |m| puts "rdoc #{c.full_name} #{m.singleton} #{m.name} #{m.params} #{m.call_seq.inspect} #{m.comment.to_s.inspect}" }
end
YARD::Registry.clear; YARD.parse(Dir["#{tree}/lib/**/*.rb"])
YARD::Registry.all.sort_by(&:path).each { |o| puts "yard #{o.path} #{o.type} #{o.respond_to?(:parameters) ? o.parameters.inspect : ''} #{o.respond_to?(:visibility) ? o.visibility : ''} #{o.docstring.to_s.inspect}" }
