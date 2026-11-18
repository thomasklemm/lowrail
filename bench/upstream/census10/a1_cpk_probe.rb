# Lead A1 exactness: composite-key and disable_joins associations; counts calls into a custom key type's ==/eql?/hash
# while association scopes build, and diffs the SQL between trees (run per tree, diff outputs).
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"; require "active_support/core_ext"; require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
$calls = Hash.new(0)
class KeyType < ActiveModel::Type::Integer
  def ==(o) = ($calls[:type_eq] += 1; super)
  alias eql? ==
  def hash = ($calls[:type_hash] += 1; super)
end
ActiveRecord::Schema.define do
  create_table(:shops) { |t| t.string :name }
  create_table(:orders, primary_key: [:shop_id, :id]) { |t| t.integer :shop_id; t.integer :id; t.string :state }
  create_table(:items) { |t| t.integer :shop_id; t.integer :order_id; t.string :sku }
  create_table(:tags) { |t| t.integer :item_id; t.string :name }
end
class Shop < ActiveRecord::Base; has_many :orders; has_many :items, through: :orders; has_many :tags, through: :items, disable_joins: true; end
class Order < ActiveRecord::Base
  self.primary_key = [:shop_id, :id]
  attribute :shop_id, KeyType.new
  belongs_to :shop
  has_many :items, foreign_key: [:shop_id, :order_id]
  has_many :open_items, -> { where(sku: "a") }, class_name: "Item", foreign_key: [:shop_id, :order_id]
end
class Item < ActiveRecord::Base
  attribute :shop_id, KeyType.new
  belongs_to :order, foreign_key: [:shop_id, :order_id]
  has_many :tags
end
class Tag < ActiveRecord::Base; belongs_to :item; end
s = Shop.create!(name: "s"); o = Order.create!(id: [s.id, 1], state: "x")
i = Item.create!(shop_id: s.id, order_id: 1, sku: "a"); Tag.create!(item_id: i.id, name: "t")
cases = {
  "cpk_has_many" => -> { o.items.reset; [o.items.to_a.size, o.items.to_sql] },
  "cpk_has_many_scoped" => -> { o.open_items.reset; [o.open_items.to_a.size, o.open_items.to_sql] },
  "cpk_belongs_to" => -> { i.association(:order).reset; [i.order.id] },
  "through_cpk" => -> { s.items.reset; [s.items.to_a.size, s.items.to_sql] },
  "disable_joins" => -> { s.tags.reset; [s.tags.to_a.map(&:name)] },
  "joins_cpk" => -> { [Order.joins(:items).to_sql] },
}
cases.each do |name, fn|
  out = fn.(); $calls.clear; out = fn.()
  puts "#{name} #{$calls.sort.to_h} #{out.inspect}"
end
