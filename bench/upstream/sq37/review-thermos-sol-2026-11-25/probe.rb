require "active_record"
require "active_record/connection_adapters/sqlite3_adapter"
require "minitest/mock"
require "json"

puts JSON.generate(ruby: RUBY_VERSION, rails: ActiveRecord.version.to_s,
  sqlite: SQLite3::Database.new(":memory:").get_first_value("SELECT sqlite_version()"))

class ReviewWidget < ActiveRecord::Base
  self.table_name = "widgets"
end

checks = {
  raw_sql: ->(connection) { connection.select_value("SELECT name FROM widgets WHERE id = 1") },
  columns: ->(connection) { connection.columns("widgets").map(&:name) },
  table_exists: ->(connection) { connection.table_exists?("widgets") },
  model_column_names: ->(_) { ReviewWidget.column_names },
  model_primary_key: ->(_) { ReviewWidget.primary_key },
  model_find: ->(_) { ReviewWidget.find(1).name },
  model_create: ->(_) { ReviewWidget.create!(name: "second").name },
  table_create: ->(connection) { connection.create_table(:gadgets); connection.columns(:gadgets).map(&:name) }
}

checks.each do |name, check|
  begin
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ReviewWidget.reset_column_information
    connection = ActiveRecord::Base.lease_connection
    connection.execute("CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT)")
    connection.execute("INSERT INTO widgets VALUES (1, 'first')")
    puts JSON.generate(check: name, result: check.call(connection))
  rescue => error
    puts JSON.generate(check: name, error: error.class.name, message: error.message.lines.first.strip)
  ensure
    ActiveRecord::Base.remove_connection
  end
end

%w[3.35.5 3.36.0 3.37.0 3.37.1 3.100.0].each do |version|
  connection = ActiveRecord::ConnectionAdapters::SQLite3Adapter.new(adapter: "sqlite3", database: ":memory:")
  begin
    connection.stub(:database_version, ActiveRecord::ConnectionAdapters::SQLite3Adapter::Version.new(version)) do
      puts JSON.generate(connect_version: version, connected: connection.connect!.connected?)
    end
  rescue => error
    puts JSON.generate(connect_version: version, error: error.class.name, message: error.message.lines.first.strip)
  ensure
    connection.disconnect!
  end
end
