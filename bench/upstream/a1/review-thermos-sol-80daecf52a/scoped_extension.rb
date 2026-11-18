require_relative "../followup-81/head"

KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "key#{i}" }
ActiveRecord::Schema.define do
  create_table(:extension_owners, force: true) { |t| KEYS.each { |key| t.integer key } }
  create_table(:extension_children, force: true) { |t| KEYS.each { |key| t.integer key } }
  create_table(:extension_links, force: true) do |t|
    t.integer :child_id
    KEYS.each { |key| t.integer key }
  end
end

$offset = 0
$events = []
class ExtensionInteger < ActiveModel::Type::Integer
  def serialize(value)
    $events << [:serialize_first_key, $offset] if value == 1
    super(value) + $offset
  end
end

module OffsetExtension
  def self.extended(relation)
    $offset += 100
    $events << [:extended, $offset]
  end
end

class ExtensionChild < ActiveRecord::Base
  KEYS.each { |key| attribute key, ExtensionInteger.new }
end

class ExtensionLink < ActiveRecord::Base
  KEYS.each { |key| attribute key, ExtensionInteger.new }
  belongs_to :child, class_name: "ExtensionChild"
end

class ExtensionOwner < ActiveRecord::Base
  has_many :children, class_name: "ExtensionChild", primary_key: KEYS, foreign_key: KEYS, extend: OffsetExtension
  has_many :scoped_children, -> { all }, class_name: "ExtensionChild", primary_key: KEYS, foreign_key: KEYS, extend: OffsetExtension
  has_many :links, -> { all }, class_name: "ExtensionLink", primary_key: KEYS, foreign_key: KEYS
  has_many :indirect_children, through: :links, source: :child, extend: OffsetExtension
end

owner = ExtensionOwner.create!(KEYS.zip(1..).to_h)
connection = ActiveRecord::Base.connection
[0, 100, 200, 300, 400].each do |offset|
  connection.execute("INSERT INTO extension_children (#{KEYS.join(',')}) VALUES (#{KEYS.each_index.map { |i| i + 1 + offset }.join(',')})")
  connection.execute("INSERT INTO extension_links (child_id,#{KEYS.join(',')}) VALUES (#{offset / 100 + 1},#{KEYS.each_index.map { |i| i + 1 + offset }.join(',')})")
end

[false, true].product(%i[children scoped_children indirect_children]).each do |flag, name|
  keep(flag)
  $offset = 0
  $events = []
  owner.association(name).reset_scope
  records = owner.association(name).scope.pluck(:id)
  p [flag, name, records, $offset, $events]
end
