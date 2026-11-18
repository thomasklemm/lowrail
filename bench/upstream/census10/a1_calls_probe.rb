# Count calls into user-reachable equality (value ==/eql?/hash and type ==/hash) during association scope builds.
eval(File.read(File.expand_path("~/workspace/repo/bench/upstream/census10/assoc_micro.rb")).sub(/^n = Integer.*\z/m, ""), TOPLEVEL_BINDING)
class KeyType < ActiveModel::Type::Integer
  $calls = Hash.new(0)
  def ==(o) = ($calls[:type_eq] += 1; super)
  alias eql? ==
  def hash = ($calls[:type_hash] += 1; super)
end
Post.attribute :author_id, KeyType.new
Comment.attribute :post_id, KeyType.new
Author.attribute :id, KeyType.new
Post.attribute :id, KeyType.new
%w[has_many has_many_scoped has_many_through has_many_as has_one belongs_to joins_has_many joins_through].each do |c|
  CASES[c].()
  $calls.clear
  10.times { CASES[c].() }
  puts "#{c} #{$calls.sort.to_h}"
end
$calls.clear
a = Post.where(author_id: 1).where_clause; b = Post.where(author_id: 1).where_clause
a - b
puts "control #{$calls.sort.to_h}"
