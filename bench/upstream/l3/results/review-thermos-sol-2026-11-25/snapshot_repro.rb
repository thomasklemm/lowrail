# frozen_string_literal: true

require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:examples) { |t| t.string :a; t.string :b }
end

class Example < ActiveRecord::Base
end

record = Example.new(a: "trigger", b: "old")
input = Object.new
input.define_singleton_method(:to_s) { record.b = "changed"; "converted" }
record.a = input
puts "dumped=#{record.attributes_for_database.fetch("b").inspect} current=#{record.b.inspect}"
