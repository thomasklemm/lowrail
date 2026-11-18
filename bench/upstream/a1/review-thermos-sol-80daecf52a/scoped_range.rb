require_relative "../followup-81/head"

KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "key#{i}" }
ActiveRecord::Schema.define do
  create_table(:scoped_range_owners, force: true) { |t| KEYS.each { |key| t.integer key } }
  create_table(:scoped_range_children, force: true) { |t| KEYS.each { |key| t.integer key } }
end

class ScopedRangeChild < ActiveRecord::Base; end
class ScopedRangeOwner < ActiveRecord::Base
  has_many :children, -> { all }, class_name: "ScopedRangeChild", primary_key: KEYS, foreign_key: KEYS
end

[false, true].each do |flag|
  keep(flag)
  owner = ScopedRangeOwner.new(KEYS.index_with(1).merge("key0" => 2**70))
  begin
    p [flag, owner.association(:children).scope.pluck(:id)]
  rescue => error
    p [flag, error.class, error.message]
  end
end
