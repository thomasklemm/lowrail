require_relative "head"
ActiveRecord::Schema.define do
  create_table(:parents, force: true)
  create_table(:children, force: true) { |t| t.integer :parent_id; t.string :parent_type; t.string :label }
  create_table(:tweaks, force: true) { |t| t.integer :parent_id }
end
$phase = 0
$serialized = 0
class PhaseString < ActiveRecord::Type::String
  def serialize(value) = ($serialized += 1; $phase.zero? ? super : "#{super}X")
end
class Child < ActiveRecord::Base
  attribute :parent_type, PhaseString.new
  default_scope { where(parent_type: "Parent") }
end
class Tweak < ActiveRecord::Base; end
class Parent < ActiveRecord::Base
  has_many :children, as: :parent
  has_many :tweaks, -> { $phase = 100; all }
end
parent = Parent.create!
Tweak.create!(parent_id: parent.id)
c = ActiveRecord::Base.connection
%w[Parent ParentX].each { |t| c.execute("INSERT INTO children (parent_id,parent_type,label) VALUES (#{parent.id},'#{t}','#{t}')") }
[false, true].each do |flag|
  keep(flag)
  $phase = 0; $serialized = 0
  sql = Parent.joins(:children, :tweaks).to_sql
  $phase = 0
  p [flag, sql.scan(/"parent_type" = '(\w+)'/).flatten, Parent.joins(:children, :tweaks).pluck("children.label")]
end
