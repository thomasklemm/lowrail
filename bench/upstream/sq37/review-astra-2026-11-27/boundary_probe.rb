require "active_record"
require "active_record/connection_adapters/sqlite3_adapter"
require "json"

adapter = ActiveRecord::ConnectionAdapters::SQLite3Adapter
version_class = adapter::Version
version_subclass = Class.new(version_class)
string_subclass = Class.new(String)
duck_class = Class.new do
  include Comparable
  def initialize(value) = @value = value
  def <=>(other) = @value.split(".").map(&:to_i) <=> other.split(".").map(&:to_i)
  def to_s = @value
end

versions = %w[3.9.0 3.34.9 3.35.0 3.35.5 3.36.0 3.36.99 3.37.0 3.37.1 3.44.2 3.100.0 4.0.0]
shapes = {
  version: ->(v) { version_class.new(v) },
  version_subclass: ->(v) { version_subclass.new(v) },
  frozen_version: ->(v) { version_class.new(v).freeze },
  duck: ->(v) { duck_class.new(v) },
  string: ->(v) { v },
  string_subclass: ->(v) { string_subclass.new(v) },
  frozen_string: ->(v) { v.freeze }
}
results = shapes.flat_map do |shape, factory|
  versions.map do |version|
    object = factory.call(version)
    connection = adapter.new(adapter: "sqlite3", database: ":memory:")
    connection.define_singleton_method(:database_version) { object }
    result = begin
      { result: connection.check_version }
    rescue => error
      { error: error.class.name, message: error.message }
    end
    { shape: shape, version: version, comparison: object <=> "3.37.0", **result }
  end
end
puts JSON.pretty_generate(results)
