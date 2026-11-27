require "active_record"
require "active_record/connection_adapters/sqlite3_adapter"
require "minitest/mock"
require "json"

Adapter = ActiveRecord::ConnectionAdapters::SQLite3Adapter
class VersionSubclass < Adapter::Version; end
class DuckVersion
  def initialize(value)
    @version = Adapter::Version.new(value)
  end

  def <(other) = @version < other
  def to_s = @version.to_s
end

side = ENV.fetch("REVIEW_SIDE")
minimum = side == "base" ? [3, 35, 0] : [3, 37, 0]
puts JSON.generate(side: side, ruby: RUBY_DESCRIPTION, rails: ActiveRecord.version.to_s,
  actual_sqlite: SQLite3::Database.new(":memory:").get_first_value("SELECT sqlite_version()"))
count = 0
%w[3.34.9 3.35.0 3.35.5 3.36.0 3.36.99 3.37.0 3.37.1 3.44.2 3.100.0 4.0.0].each do |text|
  {
    version: Adapter::Version.new(text),
    frozen_version: Adapter::Version.new(text).freeze,
    subclass: VersionSubclass.new(text),
    duck: DuckVersion.new(text)
  }.each do |kind, version|
    connection = Adapter.new(adapter: "sqlite3", database: ":memory:")
    reject = (text.split(".").map(&:to_i) <=> minimum) == -1
    begin
      result = connection.stub(:database_version, version) { connection.connect!.connected? }
      raise "accepted below minimum: #{text}" if reject
      raise "did not connect" unless result == true
      puts JSON.generate(version: text, representation: kind, connected: result)
    rescue RuntimeError => error
      expected = "Your version of SQLite (#{text}) is too old. Active Record supports SQLite >= #{minimum.join(".")}."
      raise unless reject && error.message == expected && !connection.connected?
      puts JSON.generate(version: text, representation: kind, error: error.class.name,
        message: error.message, disconnected: !connection.connected?)
    ensure
      connection.disconnect!
    end
    count += 1
  end
end
puts "BOUNDARY_CASES_PASSED=#{count}"
