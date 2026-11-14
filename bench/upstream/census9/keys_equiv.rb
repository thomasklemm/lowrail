# frozen_string_literal: true

# keys_equiv.rb: on a Rails checkout in RAILS, checks that
# LazyIndexedAttributeSet#keys' candidate list `row_keys | type_keys |
# cached_names` equals `row_keys` (same names, same order) for records in many
# states: new, loaded, partial and aliased selects, STI, the attribute API,
# written, dirty, reloaded, dup, becomes, saved, Marshal/YAML round trips.
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "yaml"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:items) { |t| t.string :type; t.string :name; t.integer :n, default: 3; t.json :meta; t.text :meta2; t.timestamps }
end
class Item < ActiveRecord::Base
  attribute :virt, :string, default: "v"
  attribute :n, :string
  serialize :meta2, coder: JSON
end
class Sub < Item; attribute :sub_only, :integer, default: 1; end
class Plain < ActiveRecord::Base; self.table_name = "items"; self.inheritance_column = nil; end
Item.create!(name: "a", meta: { "x" => 1 }); Sub.create!(name: "b")

checked = 0
check = lambda do |label, rec|
  set = rec.instance_variable_get(:@attributes)
  return unless set.is_a?(ActiveModel::LazyIndexedAttributeSet)
  old = set.send(:row_keys) | set.instance_variable_get(:@ctx).type_keys | set.send(:cached_names)
  new = set.send(:row_keys)
  raise "#{label}: #{old.inspect} != #{new.inspect}" unless old == new
  checked += 1
end
recs = {
  "new" => Item.new, "new_sub" => Sub.new(name: "x"), "plain_new" => Plain.new,
  "loaded" => Item.first, "loaded_sub" => Sub.first, "plain" => Plain.first,
  "partial" => Item.select(:id, :name).first, "alias" => Item.select("items.*, n + 1 AS n1, 'z' AS zz").first,
  "only_alias" => Item.select("1 AS one").first, "joined" => Item.joins("JOIN items i2 ON i2.id = items.id").select("items.*, i2.name AS other").first,
}
recs.each do |label, r|
  check.(label, r)
  r.name if r.has_attribute?(:name); check.("#{label} read", r)
  r.virt = "w" if r.respond_to?(:virt=); check.("#{label} write", r)
  r.changes; check.("#{label} changes", r)
  check.("#{label} dup", r.dup)
  check.("#{label} becomes", r.becomes(Plain)) rescue nil
  if r.persisted? && r.has_attribute?(:id) && r.has_attribute?(:type)
    r.save!; check.("#{label} saved", r)
    r.reload; check.("#{label} reloaded", r)
    check.("#{label} marshal", Marshal.load(Marshal.dump(r)))
  end
end
puts "checked #{checked} sets, all equal"
