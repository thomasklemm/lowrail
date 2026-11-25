# frozen_string_literal: true

require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false

records = {}
[6, 100, 300, 1500].each do |width|
  table = "width_#{width}"
  ActiveRecord::Schema.define do
    create_table(table) do |t|
      (width - 3).times do |i|
        t.public_send([:string, :integer, :boolean][i % 3], "c#{i}")
      end
      t.timestamps
    end
  end
  klass = Object.const_set("Width#{width}", Class.new(ActiveRecord::Base))
  klass.table_name = table
  values = (width - 3).times.to_h { |i| ["c#{i}", ["Hello", i, true][i % 3]] }
  record = klass.find(klass.create!(values).id)
  record.attributes_for_database
  records[width] = record
end

wide = records.fetch(6).dup
wide.c0 = "x" * (1024 * 1024)
wide.attributes_for_database

class ExpensiveType < ActiveModel::Type::Value
  def serialize(value) = value.reverse
  def changed_in_place?(_raw, _cast) = true
end

class Expensive < ActiveRecord::Base
  self.table_name = "width_6"
  attribute :c0, ExpensiveType.new
end
expensive = Expensive.instantiate("c0" => "x" * (1024 * 1024))
expensive.attributes_for_database
cold_class = records.fetch(1500).class
cold_values = records.fetch(1500).attributes

Benchmark.ips do |x|
  x.config(warmup: 0.5, time: 1.5)
  records.each do |width, record|
    x.report("w#{width} Marshal.dump") { Marshal.dump(record) }
    x.report("w#{width} for_database") { record.attributes_for_database }
  end
  x.report("w6 Marshal 1MiB string") { Marshal.dump(wide) }
  x.report("w6 serialize 1MiB every call") { expensive.attributes_for_database }
  x.report("w1500 cold for_database") { cold_class.instantiate(cold_values).attributes_for_database }
end
