require_relative "../followup-81/head"

KEYS = Array.new(Integer(ENV.fetch("WIDTH", "17"))) { |i| "key#{i}" }
ActiveRecord::Schema.define do
  create_table(:removed_parents, force: true)
  create_table(:removed_children, force: true) do |t|
    t.integer :parent_id
    KEYS.each { |key| t.integer key }
  end
end

class RemovedChild < ActiveRecord::Base
  default_scope { where(KEYS.index_with(1).merge("key0" => 2**70)) }
end

class RemovedParent < ActiveRecord::Base
  has_many :children, -> { unscope(:where) }, class_name: "RemovedChild", foreign_key: :parent_id
end

parent = RemovedParent.create!
RemovedChild.unscoped.create!(parent_id: parent.id)
[false, true].each do |flag|
  keep(flag)
  begin
    p [flag, RemovedParent.joins(:children).pluck(:id)]
  rescue => error
    p [flag, error.class, error.message]
  end
end
