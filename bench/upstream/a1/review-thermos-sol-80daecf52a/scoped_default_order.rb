require_relative "../followup-81/head"

KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "key#{i}" }
ActiveRecord::Schema.define do
  create_table(:ordered_owners, force: true) { |t| KEYS.each { |key| t.integer key } }
  create_table(:ordered_children, force: true) do |t|
    t.integer :flag
    KEYS.each { |key| t.integer key }
  end
end

$offset = 0
$events = []
class OrderedInteger < ActiveModel::Type::Integer
  def serialize(value)
    $events << [:key, value, $offset]
    super(value) + $offset
  end
end

class FlagInteger < ActiveModel::Type::Integer
  def serialize(value)
    $events << [:flag, value]
    $offset = 100
    super
  end
end

class OrderedChild < ActiveRecord::Base
  KEYS.each { |key| attribute key, OrderedInteger.new }
  attribute :flag, FlagInteger.new
  default_scope { where(flag: 1) }
end

class OrderedOwner < ActiveRecord::Base
  has_many :children, class_name: "OrderedChild", primary_key: KEYS, foreign_key: KEYS
  has_many :scoped_children, -> { all }, class_name: "OrderedChild", primary_key: KEYS, foreign_key: KEYS
  has_many :unscoped_children, -> { unscoped }, class_name: "OrderedChild", primary_key: KEYS, foreign_key: KEYS
end

owner = OrderedOwner.create!(KEYS.zip(1..).to_h)
connection = ActiveRecord::Base.connection
[0, 100].each do |offset|
  connection.execute("INSERT INTO ordered_children (flag,#{KEYS.join(',')}) VALUES (1,#{KEYS.each_index.map { |i| i + 1 + offset }.join(',')})")
end

[false, true].product(%i[children scoped_children unscoped_children]).each do |flag, name|
  keep(flag)
  $offset = 0
  $events = []
  owner.association(name).reset_scope
  records = owner.association(name).scope.pluck(:id)
  p [flag, name, records, $events]
end
