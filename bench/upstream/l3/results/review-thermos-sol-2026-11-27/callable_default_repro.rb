require "bundler/setup"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:default_records) do |table|
    table.string :title
    table.string :author_name
  end
end

record = nil
klass = Class.new(ActiveRecord::Base) do
  self.table_name = "default_records"
end
klass.attribute :title, :string, default: -> { record.author_name = "Mary"; "title" }
record = klass.new(author_name: "David")

puts "before_type_cast=#{record.attributes_before_type_cast.inspect}"
puts "author_name_after=#{record.author_name.inspect}"
