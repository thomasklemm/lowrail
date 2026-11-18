# frozen_string_literal: true

require "json"
require_relative "../followup-81/head"

KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "k#{i}" }
MODE = ENV.fetch("MODE", "finite")
ActiveRecord::Schema.define do
  create_table(:probe_owners, force: true) { |t| KEYS.each { |key| t.integer key } }
  create_table(:probe_children, force: true) do |t|
    t.integer :owner_id
    t.string :owner_type
    t.string :type
    t.string :label
    KEYS.each { |key| t.integer key }
  end
  create_table(:probe_paths, force: true) { |t| t.integer :owner_id }
  create_table(:probe_links, force: true) { |t| t.integer :owner_id; t.integer :path_id; t.integer :child_id }
  create_table(:probe_tweaks, force: true) { |t| t.integer :owner_id }
end

$phase = 0
$extensions = 0
class ProbeInteger < ActiveRecord::Type::Integer
  def serialize(value) = super(value)&.+(MODE == "phase" ? $phase : 0)
end

module ProbeExtension
  def self.extended(relation)
    $extensions += 1
    $phase += 100
  end
end

class ProbeChild < ActiveRecord::Base
  attribute :k0, ProbeInteger.new
  default_scope { where(KEYS.index_with(1).merge("k0" => MODE == "range" ? 2**70 : 1)) }
end
class ProbeSpecialChild < ProbeChild; end
class ProbePath < ActiveRecord::Base
  has_many :links, class_name: "ProbeLink", foreign_key: :path_id
end
class ProbeLink < ActiveRecord::Base
  belongs_to :child, class_name: "ProbeChild"
  belongs_to :special_child, class_name: "ProbeSpecialChild", foreign_key: :child_id
  belongs_to :scoped_child, -> { all }, class_name: "ProbeChild", foreign_key: :child_id
end
class ProbeTweak < ActiveRecord::Base; end
class ProbeOwner < ActiveRecord::Base
  has_many :children, class_name: "ProbeChild", foreign_key: :owner_id
  has_many :poly_children, class_name: "ProbeChild", as: :owner
  has_many :special_children, class_name: "ProbeSpecialChild", foreign_key: :owner_id
  has_many :composite_children, class_name: "ProbeChild", primary_key: KEYS, foreign_key: KEYS
  has_many :extended_children, class_name: "ProbeChild", foreign_key: :owner_id, extend: ProbeExtension
  has_many :scoped_children, -> { all }, class_name: "ProbeChild", foreign_key: :owner_id
  has_many :scoped_poly_children, -> { unscope(where: :owner_type).where(owner_type: "OtherOwner") }, class_name: "ProbeChild", as: :owner
  has_many :removed_children, -> { unscope(:where) }, class_name: "ProbeChild", foreign_key: :owner_id
  has_many :paths, class_name: "ProbePath", foreign_key: :owner_id
  has_many :direct_links, class_name: "ProbeLink", foreign_key: :owner_id
  has_many :through_children, through: :direct_links, source: :child
  has_many :extended_through_children, through: :direct_links, source: :child, extend: ProbeExtension
  has_many :scoped_through_children, through: :direct_links, source: :scoped_child
  has_many :sti_through_children, through: :direct_links, source: :special_child
  has_many :nested_links, through: :paths, source: :links
  has_many :nested_children, through: :nested_links, source: :child
  has_many :tweaks, -> { $phase = 100; all }, class_name: "ProbeTweak", foreign_key: :owner_id
end

owner = ProbeOwner.create!(KEYS.index_with(1))
other = ProbeOwner.create!(KEYS.index_with(2))
path = ProbePath.create!(owner_id: owner.id)
ProbeTweak.create!(owner_id: owner.id)
connection = ActiveRecord::Base.connection
[
  [owner.id, "ProbeOwner", "ProbeSpecialChild", 1, 1, "chosen1"],
  [owner.id, "ProbeOwner", "ProbeSpecialChild", 101, 1, "chosen101"],
  [owner.id, "OtherOwner", "ProbeChild", 1, 1, "other-type"],
  [other.id, "ProbeOwner", "ProbeSpecialChild", 1, 1, "other-owner"],
  [owner.id, "ProbeOwner", "ProbeChild", 1, 2, "outside-default"],
].each do |owner_id, owner_type, type, first, rest, label|
  values = [owner_id, connection.quote(owner_type), connection.quote(type), connection.quote(label), first, *Array.new(KEYS.size - 1, rest)]
  connection.execute("INSERT INTO probe_children (owner_id,owner_type,type,label,#{KEYS.join(',')}) VALUES (#{values.join(',')})")
end
ProbeLink.create!(owner_id: owner.id, path_id: path.id, child_id: 1)
ProbeLink.create!(owner_id: owner.id, path_id: path.id, child_id: 2)

names = %i[children poly_children special_children composite_children extended_children scoped_children
  scoped_poly_children removed_children through_children extended_through_children scoped_through_children
  sti_through_children nested_children]
[false, true].product(names, %i[joins left_joins eager_load includes_refs associated]).each do |flag, name, operation|
  keep(flag)
  $phase = 0
  $extensions = 0
  begin
    relation = case operation
    when :includes_refs then ProbeOwner.includes(name).references(ProbeChild.table_name)
    when :associated then ProbeOwner.where.associated(name)
    else ProbeOwner.public_send(operation, name)
    end
    relation = relation.joins(:tweaks) if MODE == "phase"
    records = relation.to_a
    loaded = if %i[eager_load includes_refs].include?(operation)
      records.map { |record| [record.id, record.public_send(name).map(&:label).sort] }.sort
    end
    puts JSON.generate([flag, name, operation, records.map(&:id).sort, loaded, $extensions])
  rescue => error
    puts JSON.generate([flag, name, operation, error.class.name, error.message.lines.first.strip])
  end
end
