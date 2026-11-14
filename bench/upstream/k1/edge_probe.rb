# frozen_string_literal: true

# K1 second review: edge cases the author's keys_probe.rb does not cover. Prints one line per check, to be diffed
# between Rails trees.
#   BUNDLE_GEMFILE=<suite for TREE> ruby bench/upstream/k1/edge_probe.rb > edge-TREE.txt
require "bundler/setup"
require "active_record"
require "yaml"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:items) do |t|
    t.string :type
    t.string :b
    t.integer :a
    t.string :c, default: "dc"
  end
end

class Item < ActiveRecord::Base
  # Declared out of column order and with a virtual attribute, so type order differs from column order.
  attribute :z_virtual, :string, default: "zv"
  attribute :a, :integer
end
class Sub < Item
  attribute :sub_only, :integer, default: 7
end
class Other < ActiveRecord::Base
  self.table_name = "items"
  self.inheritance_column = nil
  attribute :other_only, :string
end

Item.create!(b: "x", a: 1)
Sub.create!(b: "y", a: 2)

def show(label)
  value = yield
  puts "#{label}: #{value.inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message.lines.first.chomp}"
end

def record_report(label, r)
  set = r.instance_variable_get(:@attributes)
  show("#{label} set_class") { set.class.name }
  show("#{label} keys") { set.keys }
  show("#{label} keys_frozen") { set.keys.frozen? }
  show("#{label} keys_fresh") { !set.keys.equal?(set.keys) }
  show("#{label} attribute_names") { r.attribute_names }
  show("#{label} attributes") { r.attributes }
  show("#{label} changed?") { r.changed? }
  show("#{label} changes") { r.changes }
  show("#{label} inspect") { r.inspect }
  show("#{label} serializable_hash") { r.serializable_hash }
  show("#{label} as_json keys") { r.as_json.keys }
  show("#{label} yaml") { YAML.dump(r).lines.grep(/name:/).map(&:strip) }
  show("#{label} marshal round trip keys") { Marshal.load(Marshal.dump(r)).attribute_names }
end

record_report("loaded", Item.find(1))
record_report("new", Item.new(b: "n"))
record_report("sti", Item.find(2))
record_report("partial", Item.select(:c, :id).first)
record_report("alias", Item.select("items.*, 1 AS extra").first)

r = Item.find(1); r.readonly!
record_report("readonly", r)
show("readonly save") { r.save }

r = Item.find(1); r.b = "changed"; r.freeze
record_report("frozen dirty", r)
show("frozen write") { r.b = "q" }

r = Item.new(b: "fresh").freeze
record_report("frozen new", r)

r = Item.find(1).becomes(Other)
record_report("becomes", r)
r = Item.find(1); r.b = "w"; r = r.becomes(Sub)
record_report("becomes sub dirty", r)
r = Item.find(1).becomes(Other).freeze
record_report("becomes frozen", r)
r = Item.find(1).becomes!(Sub)
record_report("becomes!", r)

# keys mutates the Array it builds; callers that mutate what keys returns must not see each other.
r = Item.find(1)
set = r.instance_variable_get(:@attributes)
k = set.keys
k << "junk"
k.clear
show("after mutating returned keys") { [set.keys, set.send(:row_keys), set.indexes.keys] }

# Threads: many threads call keys on one shared record (frozen and not) and compare to the expected list.
[Item.find(1), Item.find(1).freeze, Item.new(b: "t")].each_with_index do |rec, i|
  expected = rec.attribute_names.dup
  bad = 8.times.map do
    Thread.new { 2_000.times.count { rec.attribute_names != expected || rec.changed? } }
  end.sum(&:value)
  show("threads #{i} mismatches") { bad }
end

# Ractor: a deep-frozen, shareable attribute set read from another Ractor.
Warning[:experimental] = false
r = Item.find(1).freeze
shared = Ractor.make_shareable(r.instance_variable_get(:@attributes).dup.freeze)
show("ractor shareable") { Ractor.shareable?(shared) }
show("ractor keys") do
  Ractor.new(shared) { |s| s.keys }.then { |rr| rr.respond_to?(:value) ? rr.value : rr.take }
end
