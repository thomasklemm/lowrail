require "bundler/setup"
require "active_record"
require "benchmark/ips"
require "json"

abort "wrong Rails" unless ActiveRecord::Base.method(:find).source_location.first.start_with?(ENV.fetch("RAILS") + "/")
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
width = Integer(ENV.fetch("WIDTH", "30"))
ActiveRecord::Schema.define do
  create_table :samples do |t|
    (width - 1).times { |i| t.public_send(%i[string integer boolean][i % 3], "c#{i}") }
  end
end
class Sample < ActiveRecord::Base; end
values = (width - 1).times.to_h { |i| ["c#{i}", ["Hello", 123, true][i % 3]] }
record = Sample.find(Sample.create!(values).id)
if ENV["LARGE"]
  type = Class.new(ActiveModel::Type::String) do
    def serialize(value) = value.reverse
    def changed_in_place?(*args) = true
  end.new
  Sample.attribute :c0, type
  record = Sample.instantiate(record.attributes_for_database.merge("c0" => "x" * (128 * 1024 * 1024)))
end
operations = {
  "Marshal.dump" => -> { Marshal.dump(record) },
  "attributes_for_database" => -> { record.attributes_for_database },
  "attributes_before_type_cast" => -> { record.attributes_before_type_cast }
}
operations = operations.slice("attributes_for_database") if ENV["LARGE"]
puts RUBY_DESCRIPTION
puts "width=#{width} large=#{ENV["LARGE"] || "false"}"
unless ENV["LARGE"]
  allocations = operations.to_h do |name, operation|
    100.times { operation.call }
    GC.start
    before = GC.stat(:total_allocated_objects)
    10_000.times { operation.call }
    [name, (GC.stat(:total_allocated_objects) - before) / 10_000.0]
  end
  puts JSON.generate(allocations)
end
Benchmark.ips do |x|
  x.config(time: 1, warmup: 1)
  operations.each { |name, operation| x.report(name, &operation) }
end
