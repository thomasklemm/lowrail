require_relative "../followup-81/head"

KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "key#{i}" }
ActiveRecord::Schema.define do
  create_table(:hash_phase_owners, force: true) { |t| KEYS.each { |key| t.integer key } }
  create_table(:hash_phase_children, force: true) do |t|
    t.string :label
    KEYS.each { |key| t.integer key }
  end
end

$hashes = 0
class HashPhaseInteger < ActiveModel::Type::Integer
  def hash
    $hashes += 1
    super
  end
end

class HashPhaseString < ActiveModel::Type::String
  def serialize(value) = "#{super}#{$hashes}"
end

class HashPhaseChild < ActiveRecord::Base
  KEYS.each { |key| attribute key, HashPhaseInteger.new }
  attribute :label, HashPhaseString.new
end

class HashPhaseOwner < ActiveRecord::Base
  has_many :children, -> { $hashes = 0; where(label: "chosen") }, class_name: "HashPhaseChild", primary_key: KEYS, foreign_key: KEYS
end

owner = HashPhaseOwner.create!(KEYS.zip(1..).to_h)
connection = ActiveRecord::Base.connection
(0..200).each do |phase|
  connection.execute("INSERT INTO hash_phase_children (label,#{KEYS.join(',')}) VALUES ('chosen#{phase}',#{KEYS.each_index.map { |i| i + 1 }.join(',')})")
end

[false, true].each do |flag|
  keep(flag)
  $hashes = 0
  owner.association(:children).reset_scope
  scope = owner.association(:children).scope
  p [flag, scope.to_sql, scope.pluck(:id)]
end
