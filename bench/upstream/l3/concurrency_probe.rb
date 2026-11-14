# frozen_string_literal: true

# L3 review: attributes_for_database / attributes_before_type_cast while other threads materialize the same record,
# frozen records, and a shareable attribute set read inside a Ractor. Prints counts; run on two trees and compare.
require "bundler/setup"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false

# Yields the GVL inside every cast and serialize, so threads interleave inside materialize and inside the walk.
class SlowString < ActiveModel::Type::String
  def deserialize(v) = (Thread.pass; super)
  def cast(v) = (Thread.pass; super)
  def serialize(v) = (Thread.pass; super)
end
ActiveRecord::Type.register(:slow_string, SlowString)

ActiveRecord::Schema.define do
  create_table(:items) { |t| 20.times { |i| t.string "c#{i}" } }
end
class Item < ActiveRecord::Base
  20.times { |i| attribute "c#{i}", :slow_string }
  attribute :virtual, :slow_string, default: "v"
end
Item.create!(20.times.to_h { |i| ["c#{i}", "s#{i}"] })

# Fault injection: yield after every attribute the lazy set stores, so a second thread runs inside materialize, and
# count slots built twice (two threads both found the slot empty).
DOUBLE_BUILT = Hash.new(0)
ActiveModel::LazyIndexedAttributeSet.prepend(Module.new do
  private def store(index, attribute)
    DOUBLE_BUILT[:double] += 1 if ENV["YIELD_IN_STORE"] && lookup(index) && Thread.current[:racing]
    super.tap { Thread.pass if ENV["YIELD_IN_STORE"] }
  end

  # Between finding a slot empty and storing its attribute, so two threads can build the same slot.
  private def default_attribute(*)
    Thread.pass if ENV["YIELD_IN_STORE"] == "2"
    super
  end
end)

EXPECTED_DB = Item.find(1).attributes_for_database
EXPECTED_BTC = Item.find(1).attributes_before_type_cast
THREADS = 8
mismatch = errors = 0
200.times do
  rec = Item.find(1)
  gate = Queue.new
  threads = THREADS.times.map do |i|
    Thread.new do
      gate.pop
      Thread.current[:racing] = true
      i.even? ? [:db, rec.attributes_for_database] : [:btc, rec.attributes_before_type_cast]
    rescue => e
      [:error, e]
    end
  end
  THREADS.times { gate << true }
  threads.map(&:value).each do |kind, value|
    case kind
    when :error then errors += 1; warn value.full_message if errors == 1
    when :db then mismatch += 1 unless value == EXPECTED_DB && value.keys == EXPECTED_DB.keys
    when :btc then mismatch += 1 unless value == EXPECTED_BTC && value.keys == EXPECTED_BTC.keys
    end
  end
  # After the race every slot holds one attribute; later calls must agree with each other.
  mismatch += 1 unless rec.attributes_for_database == EXPECTED_DB
end
puts "threads: 200 records x #{THREADS} threads, mismatches #{mismatch}, errors #{errors}, " \
  "slots built twice #{DOUBLE_BUILT[:double]}"

# Frozen record: freeze materializes first, so both calls only read.
rec = Item.find(1).freeze
puts "frozen: db #{rec.attributes_for_database == EXPECTED_DB} btc #{rec.attributes_before_type_cast == EXPECTED_BTC} " \
  "frozen? #{rec.frozen?} set frozen? #{rec.instance_variable_get(:@attributes).frozen?}"
rec = Item.find(1)
rec.c3 = "w"
rec.freeze
puts "frozen dirty: db c3 #{rec.attributes_for_database['c3'].inspect} btc c3 #{rec.attributes_before_type_cast['c3'].inspect}"

# Ractor: a deeply frozen set, already materialized and with value_for_database computed, read in another Ractor.
rec = Item.find(1)
rec.attributes_for_database
set = rec.instance_variable_get(:@attributes)
result =
  begin
    shareable = Ractor.make_shareable(set.dup)
    r = Ractor.new(shareable) do |s|
      [s.values_for_database.size, s.values_before_type_cast.size]
    rescue => err
      "#{err.class}: #{err.message[0, 120]}"
    end
    r.respond_to?(:value) ? r.value : r.take
  rescue => e
    "outside: #{e.class}: #{e.message[0, 120]}"
  end
puts "ractor (prepared): #{result.inspect}"
rec = Item.find(1)
set = rec.instance_variable_get(:@attributes)
result =
  begin
    shareable = Ractor.make_shareable(set.dup)
    r = Ractor.new(shareable) do |s|
      [s.values_for_database.size, s.values_before_type_cast.size]
    rescue => err
      "#{err.class}: #{err.message[0, 120]}"
    end
    r.respond_to?(:value) ? r.value : r.take
  rescue => e
    "outside: #{e.class}: #{e.message[0, 120]}"
  end
puts "ractor (cold): #{result.inspect}"
