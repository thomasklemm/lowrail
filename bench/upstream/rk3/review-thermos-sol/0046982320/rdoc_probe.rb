require 'rdoc/rdoc'
ARGV.each do |tree|
  rdoc = RDoc::RDoc.new
  rdoc.document(['--quiet', '--dry-run', '--op', File.join(tree, '../rdoc-' + File.basename(tree)), File.join(tree, 'lib/rack/utils.rb'), File.join(tree, 'lib/rack/query_parser.rb')])
  utils = rdoc.store.find_class_or_module('Rack::Utils')
  p [File.basename(tree), utils.method_list.select { |m| m.name == 'unescape' }.map { |m| [m.name, m.singleton, m.visibility, m.params, m.call_seq, m.comment.to_s] }]
end
