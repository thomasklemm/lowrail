rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_record"
adapter = ENV.fetch("ADAPTER", "sqlite3")
ActiveRecord::Base.establish_connection(adapter: adapter, database: adapter == "sqlite3" ? ":memory:" : ENV.fetch("DATABASE"))
ActiveRecord::Schema.verbose = false
KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "k#{i}" }
ActiveRecord::Schema.define do
  create_table(:parents, force: true)
  create_table(:children, force: true) do |t|
    t.integer :parent_id
    t.string :parent_type
    KEYS.each { |k| t.integer k }
    t.string :label
  end
  create_table(:tweaks, force: true) { |t| t.integer :parent_id }
end
$phase = 0
class PhaseInt < ActiveRecord::Type::Integer
  def serialize(value) = super(value)&.+($phase)
end
class Child < ActiveRecord::Base
  attribute :k0, PhaseInt.new
  default_scope { where(KEYS.to_h { |k| [k, 1] }) }
end
class Tweak < ActiveRecord::Base; end
class Parent < ActiveRecord::Base
  has_many :children, as: :parent
  has_many :tweaks, -> { $phase = 100; all }
end
parent = Parent.create!
Tweak.create!(parent_id: parent.id)
connection = ActiveRecord::Base.connection
[1, 101].each do |key|
  values = [parent.id, connection.quote("Parent"), key, *Array.new(KEYS.size - 1, 1), connection.quote("k0=#{key}")]
  connection.execute("INSERT INTO children (parent_id,parent_type,#{KEYS.join(',')},label) VALUES (#{values.join(',')})")
end
[false, true].each do |flag|
  ActiveRecord.association_scope_keeps_owner_conditions = flag if ActiveRecord.respond_to?(:association_scope_keeps_owner_conditions=)
  $phase = 0
  sql = Parent.joins(:children, :tweaks).to_sql
  $phase = 0
  records = Parent.joins(:children, :tweaks).pluck("children.label")
  p [flag, sql[/"k0" = (\d+)/, 1], records]
end
