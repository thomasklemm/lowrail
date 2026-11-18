rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_record"
adapter = ENV.fetch("ADAPTER", "sqlite3")
ActiveRecord::Base.establish_connection(adapter: adapter, database: adapter == "sqlite3" ? ":memory:" : ENV.fetch("DATABASE"))
ActiveRecord::Migration.verbose = false
ActiveRecord.association_scope_keeps_owner_conditions = ENV.fetch("KEEP") == "1" if ActiveRecord.respond_to?(:association_scope_keeps_owner_conditions=)
$offset = 0
class OffsetType < ActiveModel::Type::Integer
  def serialize(value) = super(value) + $offset
end
KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "key#{i}" }
ActiveRecord::Schema.define do
  create_table(:wide_owners, force: true) { |t| KEYS.each { |k| t.integer k } }
  create_table(:wide_children, force: true) { |t| KEYS.each { |k| t.integer k } }
end
class WideChild < ActiveRecord::Base
  KEYS.each { |k| attribute k, OffsetType.new }
end
class WideOwner < ActiveRecord::Base
  has_many :scoped_children, -> { $offset = 100; where("1=1") }, class_name: "WideChild", primary_key: KEYS, foreign_key: KEYS
end
owner = WideOwner.create!(KEYS.zip(1..).to_h)
WideChild.create!(KEYS.zip(1..).to_h)
WideChild.create!(KEYS.zip(101..).to_h)
association = owner.association(:scoped_children)
scope = association.scope
puts scope.to_sql
puts "records #{scope.pluck(:id).inspect}"
