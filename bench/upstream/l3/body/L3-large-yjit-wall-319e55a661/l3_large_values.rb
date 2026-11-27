# frozen_string_literal: true

# L3 large values (script/upstream-bench --wall): the two 1 MiB cases thermos-sol's sweep saw at -3.0% and -2.3%
# (review-thermos-sol-2026-11-27/head-319e55a661), on a 6-column table as in sweep_ips.rb.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:width_6) do |t|
    t.string :c0
    t.integer :c1
    t.boolean :c2
    t.timestamps
  end
end

class Width6 < ActiveRecord::Base
  self.table_name = "width_6"
end

class ExpensiveType < ActiveModel::Type::Value
  def serialize(value) = value.reverse
  def changed_in_place?(_raw, _cast) = true
end

class Expensive < ActiveRecord::Base
  self.table_name = "width_6"
  attribute :c0, ExpensiveType.new
end

wide = Width6.find(Width6.create!(c0: "Hello", c1: 1, c2: true).id).dup
wide.c0 = "x" * (1024 * 1024)
wide.attributes_for_database
expensive = Expensive.instantiate("c0" => "x" * (1024 * 1024))
expensive.attributes_for_database

UpstreamBench.report("Marshal.dump, 1 MiB string") { Marshal.dump(wide) }
UpstreamBench.report("attributes_for_database, 1 MiB serialized every call") { expensive.attributes_for_database }
