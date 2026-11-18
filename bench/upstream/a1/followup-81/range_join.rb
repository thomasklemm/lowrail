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
[false, true].each do |flag|
  keep(flag)
  begin
    p [flag, Parent.joins(:children).to_a.size, Parent.joins(:children).to_sql[/1=0/]]
  rescue => e
    p [flag, e.class, e.message[0, 80]]
  end
end
