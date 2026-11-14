# activerecord-postgis-adapter 11.1.1 and activerecord-cockroachdb-adapter 8.1.2 override the private
# new_column_from_field(table_name, field, definitions) and inherit Rails' #columns.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(Module.new do
  private def new_column_from_field(table_name, field, definitions) = super
end)
class Post < ActiveRecord::Base; end
begin
  p Post.create!(title: "a").reload.title
rescue => e
  puts "#{e.class}: #{e.message}"
end
