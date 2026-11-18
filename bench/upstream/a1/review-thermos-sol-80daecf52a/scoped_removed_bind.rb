require_relative "../followup-81/head"

KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "key#{i}" }
ActiveRecord::Schema.define do
  create_table(:removed_bind_owners, force: true) { |t| KEYS.each { |key| t.integer key } }
  create_table(:removed_bind_children, force: true) do |t|
    t.string :label
    KEYS.each { |key| t.integer key }
  end
end

$phase = 0
class RemovedBindInteger < ActiveModel::Type::Integer
  def serialize(value)
    $phase = 100
    super
  end
end

class RemovedBindString < ActiveModel::Type::String
  def serialize(value) = $phase.zero? ? super : "#{super}X"
end

class RemovedBindChild < ActiveRecord::Base
  KEYS.each { |key| attribute key, RemovedBindInteger.new }
  attribute :label, RemovedBindString.new
end

class RemovedBindOwner < ActiveRecord::Base
  has_many :children, -> { $phase = 0; unscope(:where).where(label: "chosen") }, class_name: "RemovedBindChild", primary_key: KEYS, foreign_key: KEYS
end

owner = RemovedBindOwner.create!(KEYS.zip(1..).to_h)
connection = ActiveRecord::Base.connection
%w[chosen chosenX].each do |label|
  connection.execute("INSERT INTO removed_bind_children (label,#{KEYS.join(',')}) VALUES ('#{label}',#{KEYS.each_index.map { |i| i + 1 }.join(',')})")
end

[false, true].each do |flag|
  keep(flag)
  $phase = 0
  owner.association(:children).reset_scope
  scope = owner.association(:children).scope
  p [flag, scope.to_sql, scope.pluck(:id)]
end
