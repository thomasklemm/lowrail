rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord.association_scope_keeps_owner_conditions = ENV.fetch("KEEP") == "1"
$calls = Hash.new(0)
class CountingType < ActiveModel::Type::Integer
  def ==(other) = ($calls[:eq] += 1; super)
  def eql?(other) = ($calls[:eql] += 1; super)
  def hash = ($calls[:hash] += 1; super)
end
KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "key#{i}" }
ActiveRecord::Schema.define do
  create_table(:wide_owners) { |t| KEYS.each { |k| t.integer k } }
  create_table(:wide_children) { |t| KEYS.each { |k| t.integer k } }
end
class WideChild < ActiveRecord::Base
  KEYS.each { |k| attribute k, CountingType.new }
end
class WideOwner < ActiveRecord::Base
  has_many :wide_children, primary_key: KEYS, foreign_key: KEYS
  has_many :scoped_children, -> { $calls[:lambda] += 1; where("1=1") }, class_name: "WideChild", primary_key: KEYS, foreign_key: KEYS
end
owner = WideOwner.create!(KEYS.zip(1..).to_h)
WideChild.create!(KEYS.zip(1..).to_h)
%i[wide_children scoped_children].each do |name|
  owner.association(name).scope.to_sql
  owner.association(name).reset_scope
  $calls.clear
  scope = owner.association(name).scope
  puts "#{name} scope calls #{$calls.sort.to_h.inspect}"
  puts scope.to_sql
end
