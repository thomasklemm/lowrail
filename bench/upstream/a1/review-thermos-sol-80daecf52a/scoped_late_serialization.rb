require_relative "../followup-81/head"

KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "key#{i}" }
ActiveRecord::Schema.define do
  create_table(:late_owners, force: true) { |t| KEYS.each { |key| t.integer key } }
  create_table(:late_children, force: true) { |t| KEYS.each { |key| t.integer key } }
end

$offset = 0
class LateInteger < ActiveModel::Type::Integer
  def serialize(value) = super(value) + $offset
end

class LateChild < ActiveRecord::Base
  KEYS.each { |key| attribute key, LateInteger.new }
end

class LateOwner < ActiveRecord::Base
  has_many :children, class_name: "LateChild", primary_key: KEYS, foreign_key: KEYS
  has_many :scoped_children, -> { $offset = 100; all }, class_name: "LateChild", primary_key: KEYS, foreign_key: KEYS
end

owner = LateOwner.create!(KEYS.zip(1..).to_h)
[0, 100, 200].each { |offset| LateChild.create!(KEYS.zip((1 + offset)..).to_h) }

[false, true].product(%i[children scoped_children]).each do |flag, association_name|
  keep(flag)
  $offset = 0
  owner.association(association_name).reset_scope
  scope = owner.association(association_name).scope
  $offset = 200
  p [flag, association_name, scope.pluck(:id)]
end
