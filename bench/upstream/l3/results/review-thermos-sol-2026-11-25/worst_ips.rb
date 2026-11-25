# frozen_string_literal: true

require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:worst_records) do |t|
    t.string :payload
    t.integer :count
    t.boolean :flag
    t.timestamps
  end
end

class LargeSerialization < ActiveModel::Type::Value
  def serialize(value) = value.reverse
  def changed_in_place?(_raw, _cast) = true
end

class WorstRecord < ActiveRecord::Base
  attribute :payload, LargeSerialization.new
end

record = WorstRecord.instantiate("payload" => "x" * (128 * 1024 * 1024), "count" => 7, "flag" => false)
record.attributes_for_database
Benchmark.ips do |x|
  x.config(warmup: 0.5, time: 1.5)
  x.report("serialize 128MiB every call") { record.attributes_for_database }
end
