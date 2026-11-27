# frozen_string_literal: true

# Differential probe for the dirty-tracking change: prints every observable dirty
# and attribute state across record states and operations; diff the output of two trees.
require "active_record"
require "json"
require "yaml"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :items, force: true do |t|
    t.string :name
    t.string :code, default: "c0"
    t.integer :count, default: 0
    t.boolean :flag
    t.decimal :price, precision: 8, scale: 2
    t.datetime :seen_at
    t.date :day
    t.text :notes
    t.json :data
    t.text :tags
    t.binary :blob
    t.integer :lock_version, default: 0
    t.timestamps
  end
end

class Item < ActiveRecord::Base
  serialize :tags, coder: JSON
  attribute :virtual, :string, default: "v"
  attribute :price, :decimal
end

class SubItem < Item; end

class LockItem < ActiveRecord::Base
  self.table_name = "items"
  serialize :tags, coder: JSON
end

class CallbackItem < ActiveRecord::Base
  self.table_name = "items"
  serialize :tags, coder: JSON
  before_save { self.code = "cb-#{name}" if name_changed? }
  after_save { @seen = [saved_changes.keys.sort, changed?, previous_changes.keys.sort] }
  attr_reader :seen
end

T0 = Time.utc(2026, 1, 2, 3, 4, 5)
base = { name: "a", count: 1, flag: true, price: "1.50", seen_at: T0, day: Date.new(2026, 1, 2), notes: "n",
  data: { "k" => [1, 2] }, tags: ["x"], blob: "\x00\x01".b, created_at: T0, updated_at: T0 }
ID = Item.create!(base).id

def dump(label, r)
  attrs = r.attribute_names
  out = {
    changed?: r.changed?, changed: r.changed, changes: r.changes, changes_to_save: r.changes_to_save,
    has_changes_to_save?: r.has_changes_to_save?, saved_changes: r.saved_changes, previous_changes: r.previous_changes,
    attribute_names: attrs, attributes_in_database: r.attributes_in_database,
    changed_attribute_names_to_save: r.changed_attribute_names_to_save,
    before_type_cast: r.attributes_before_type_cast.transform_values(&:inspect),
    for_database: r.attributes_for_database.transform_values(&:inspect),
    attributes: r.attributes.transform_values(&:inspect),
    per: attrs.to_h { |a| [a, [r.attribute_changed?(a), r.will_save_change_to_attribute?(a), r.saved_change_to_attribute?(a),
      r.attribute_in_database(a).inspect, r.attribute_before_last_save(a).inspect, r.read_attribute_before_type_cast(a).inspect]] }
  }
  puts "#{label}: #{out.inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message}"
end

def scenario(label)
  r = yield
  dump(label, r)
rescue => e
  puts "#{label}: #{e.class}: #{e.message}"
end

scenario("find") { Item.find(ID) }
scenario("find, read") { r = Item.find(ID); r.name; r.data; r.tags; r }
scenario("find, mutate string") { r = Item.find(ID); r.name << "!"; r }
scenario("find, mutate json") { r = Item.find(ID); r.data["k"] << 3; r }
scenario("find, mutate serialized") { r = Item.find(ID); r.tags << "y"; r }
scenario("find, mutate blob") { r = Item.find(ID); r.blob << "z"; r }
scenario("find, assign") { r = Item.find(ID); r.count = 2; r }
scenario("find, assign same") { r = Item.find(ID); r.count = 1; r.name = "a"; r }
scenario("find, assign string count") { r = Item.find(ID); r.count = "1"; r }
scenario("find, save no changes") { r = Item.find(ID); r.save!; r }
scenario("find, assign, save") { r = Item.find(ID); r.count = 5; r.save!; r }
scenario("find, assign, save, read all") { r = Item.find(ID); r.count = 6; r.save!; r.attributes; r }
scenario("find, mutate string, save") { r = Item.find(ID); r.name << "?"; r.save!; r }
scenario("find, mutate json, save") { r = Item.find(ID); r.data["k"] << 9; r.save!; r }
scenario("find, mutate after save") { r = Item.find(ID); r.count = 7; r.save!; r.name << "#"; r }
scenario("find, save, mutate never read, save") { r = Item.find(ID); r.count = 8; r.save!; r.notes << "+"; r.save!; r }
scenario("find, save twice") { r = Item.find(ID); r.count = 9; r.save!; r.count = 10; r.save!; r }
scenario("find, will_change!") { r = Item.find(ID); r.notes_will_change!; r }
scenario("find, will_change!, save") { r = Item.find(ID); r.notes_will_change!; r.save!; r }
scenario("find, assign, restore") { r = Item.find(ID); r.count = 11; r.restore_attributes; r }
scenario("find, assign, clear") { r = Item.find(ID); r.count = 12; r.clear_changes_information; r }
scenario("find, clear, mutate") { r = Item.find(ID); r.clear_changes_information; r.name << "c"; r }
scenario("find, changes_applied") { r = Item.find(ID); r.name; r.changes_applied; r.name << "d"; r }
scenario("find, touch") { r = Item.find(ID); r.touch; r }
scenario("find, assign, touch") { r = Item.find(ID); r.count = 13; r.touch; r }
scenario("find, update_columns") { r = Item.find(ID); r.update_columns(count: 14); r }
scenario("find, update_column then save") { r = Item.find(ID); r.update_column(:count, 15); r.name = "b"; r.save!; r }
scenario("find, reload") { r = Item.find(ID); r.count = 16; r.save!; r.reload; r }
scenario("partial select") { Item.select(:id, :name).find(ID) }
scenario("partial select, assign, save") { r = Item.select(:id, :name, :count).find(ID); r.count = 17; r.save!; r }
scenario("extra column") { Item.select("items.*, 1 AS extra").find(ID) }
scenario("extra column, save") { r = Item.select("items.*, 1 AS extra").find(ID); r.count = 18; r.save!; r }
scenario("new") { Item.new }
scenario("new, assign, save") { r = Item.new(name: "n"); r.save!; r }
scenario("new, save, mutate default") { r = Item.new; r.save!; r.code << "x"; r }
scenario("create") { Item.create!(name: "c") }
scenario("dup") { Item.find(ID).dup }
scenario("dup, save") { r = Item.find(ID).dup; r.save!; r }
scenario("becomes") { Item.find(ID).becomes(SubItem) }
scenario("becomes, assign, save") { r = Item.find(ID).becomes(SubItem); r.count = 19; r.save!; r }
scenario("becomes!") { r = Item.find(ID).becomes!(SubItem); r }
scenario("frozen") { Item.find(ID).freeze }
scenario("destroyed") { r = Item.create!(name: "d"); r.destroy; r }
scenario("marshal") { Marshal.load(Marshal.dump(Item.find(ID))) }
scenario("marshal, save") { r = Marshal.load(Marshal.dump(Item.find(ID))); r.count = 20; r.save!; r }
scenario("lock") { r = LockItem.find(ID); r.count = 21; r.save!; r }
scenario("callbacks") { r = CallbackItem.find(ID); r.name = "e"; r.save!; dump("callbacks seen", r) || r.seen.inspect; r }
scenario("callbacks seen") { r = CallbackItem.find(ID); r.name = "f"; r.save!; puts "seen #{r.seen.inspect}"; r }
scenario("virtual attr") { r = Item.find(ID); r.virtual = "w"; r }
scenario("virtual attr, save") { r = Item.find(ID); r.virtual = "w"; r.save!; r }
scenario("save, saved_changes, then mutate original") { r = Item.find(ID); r.count = 22; r.save!; r.saved_changes; r.data["k"] << 1; r }
scenario("where.first, update!") { r = Item.where(id: ID).first; r.update!(count: 23); r }
scenario("update! read via []") { r = Item.find(ID); r[:name]; r.update!(count: 24); r }
scenario("decimal price assign same") { r = Item.find(ID); r.price = "1.5"; r }
scenario("time assign same") { r = Item.find(ID); r.seen_at = T0; r }
scenario("save, marshal") { r = Item.find(ID); r.count = 30; r.save!; Marshal.load(Marshal.dump(r)) }
scenario("save, marshal, assign, save") { r = Item.find(ID); r.count = 31; r.save!; m = Marshal.load(Marshal.dump(r)); m.name = "m"; m.save!; m }
scenario("save, yaml") { r = Item.find(ID); r.count = 32; r.save!; YAML.unsafe_load(YAML.dump(r)) }
scenario("save, dup") { r = Item.find(ID); r.count = 33; r.save!; r.dup }
scenario("save, clone, mutate") { r = Item.find(ID); r.count = 34; r.save!; c = r.clone; c.name << "k"; c }
scenario("save, freeze") { r = Item.find(ID); r.count = 35; r.save!; r.freeze }
scenario("save, becomes") { r = Item.find(ID); r.count = 36; r.save!; r.becomes(SubItem) }
scenario("save, read later") { r = Item.find(ID); r.count = 37; r.save!; [r.name, r.data, r.tags, r.seen_at]; r }
scenario("save, mutate untouched json, save") { r = Item.find(ID); r.count = 38; r.save!; r.data["k"] << 4; r.save!; r }
scenario("save, inspect") { r = Item.find(ID); r.count = 39; r.save!; puts r.inspect.gsub(/2026-11-27 [0-9:.]+/, "NOW"); r }
scenario("save, attribute_names, accessed") { r = Item.find(ID); r.name; r.count = 40; r.save!; puts r.accessed_fields.inspect; r }
scenario("final state") { Item.find(ID) }
