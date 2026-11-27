require "active_record"
require "sqlite3"
require "fileutils"

mode, database, cache = ARGV
puts "Ruby #{RUBY_VERSION}; SQLite #{SQLite3::SQLITE_VERSION}; mode=#{mode}"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: database, schema_cache_path: cache)
class Widget < ActiveRecord::Base; end

if mode == "build"
  ActiveRecord::Base.lease_connection.create_table(:widgets, force: true) { |t| t.string :name }
  ActiveRecord::Base.connection_pool.schema_cache.dump_to(cache)
  puts "schema cache dumped"
elsif mode == "cached"
  ActiveRecord::ConnectionAdapters::SchemaReflection.check_schema_cache_dump_version = false
  ActiveRecord::Base.connection_pool.schema_cache.load!
  puts "schema cache loaded; version checking disabled"
end

record = Widget.create!(name: "asymmetric value")
raise "wrong value" unless Widget.find(record.id).name == "asymmetric value"
record.update!(name: "changed")
raise "wrong update" unless Widget.find(record.id).name == "changed"
record.destroy!
raise "still exists" if Widget.exists?(record.id)
puts "create/find/update/destroy verified"
