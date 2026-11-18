require_relative "head"
W = Integer(ENV.fetch("WIDTH", "17"))
KEYS = Array.new(W) { |i| "k#{i}" }
ActiveRecord::Schema.define do
  create_table(:parents, force: true)
  create_table(:children, force: true) { |t| t.integer :parent_id; t.string :parent_type; KEYS.each { |k| t.integer k } }
end
class Child < ActiveRecord::Base
  default_scope { where(KEYS.to_h { |k| [k, 1] }.merge("k0" => 2**70)) }
end
class Parent < ActiveRecord::Base
  has_many :children, as: :parent
end
parent = Parent.create!
[false, true].product(%i[preload eager_load includes_refs disable]).each do |flag, how|
  keep(flag)
  begin
    r = case how when :preload then Parent.preload(:children).to_a when :eager_load then Parent.eager_load(:children).to_a when :includes_refs then Parent.includes(:children).references(:children).to_a else Parent.first.children.to_a end
    p [flag, how, r.size, (r.first.children.size rescue r.size)]
  rescue => e
    p [flag, e.class, e.message[0, 80]]
  end
end
