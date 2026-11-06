# frozen_string_literal: true

rails = ENV.fetch("PDRV_RAILS", File.expand_path("../../../.corpus/rails", __dir__))
$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { File.join(rails, _1, "lib") })
require "active_record"

driver = ENV.fetch("DRIVER", "sqlite3")
prepared = ENV.fetch("PREPARED", "1") == "1"
config = case driver
when "sqlite3" then { adapter: driver, database: ":memory:" }
when "postgresql" then { adapter: driver, database: "pdrv" }
else { adapter: driver, database: "pdrv", username: "user", socket: "/run/mysqld/mysqld.sock" }
end
ActiveRecord::Base.establish_connection(**config, prepared_statements: prepared, query_cache: false)
connection = ActiveRecord::Base.lease_connection
connection.disable_query_cache!
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:driver_rows, force: true) do |t|
    t.string :name, index: true
    t.text :body
    t.bigint :score
    t.datetime :recorded_at, precision: 6
    t.string :optional
    t.binary :payload
  end
end
class DriverRow < ActiveRecord::Base
end
DriverRow.insert_all!((1..1000).map do |i|
  { id: i, name: "row-#{i}-é", body: "asymmetric text #{i} " * 20,
    score: i * -100_003, recorded_at: Time.utc(2024, 2, 29, 13, 17, 31, 123456),
    optional: i.odd? ? nil : "", payload: "\x00\xff#{i}".b }
end)
DriverRow.columns
raw = connection.raw_connection

MICRO = {}
%w[find text_find select20 select1000 wide20 wide1000 pluck].each do |shape|
  relation = case shape
  when "find" then DriverRow.where(id: 37)
  when "text_find" then DriverRow.where(name: "row-37-é")
  when "select20" then DriverRow.select(:id, :name).where(id: 1..20)
  when "select1000" then DriverRow.select(:id, :name).where(id: 1..1000)
  when "wide20" then DriverRow.where(id: 1..20)
  else DriverRow.where(id: 1..1000)
  end
  query = shape == "pluck" ? relation.select(:score) : relation
  arel = query.arel
  sql, binds, = connection.send(:to_sql_and_binds, arel)
  casted = connection.send(:type_casted_binds, binds)
  driver_work = case driver
  when "sqlite3"
    stmt = raw.prepare(sql) if prepared
    -> {
      s = prepared ? stmt.reset! : raw.prepare(sql)
      s.bind_params(casted)
      rows = s.to_a
      s.columns
      s.types
      s.close unless prepared
      rows
    }
  when "postgresql"
    statement = "pdrv_#{shape}"
    raw.prepare(statement, sql).clear if prepared
    -> {
      result = prepared ? raw.exec_prepared(statement, casted) : raw.exec_params(sql, casted)
      rows = result.values
      result.fields
      result.clear
      rows
    }
  when "mysql2"
    stmt = raw.prepare(sql) if prepared && !binds.empty?
    -> {
      s = stmt || (raw.prepare(sql) unless binds.empty?)
      result = s ? s.execute(*casted) : raw.query(sql)
      rows = result.to_a
      result.fields
      result.free
      s.close if s && !prepared
      rows
    }
  else
    -> { raw.query(sql).rows }
  end
  adapter_work = -> { connection.select_all(arel, "Driver CPU").rows }
  model_work = case shape
  when "find" then -> { DriverRow.find(37).attributes }
  when "text_find" then -> { DriverRow.find_by!(name: "row-37-é").attributes }
  when "pluck" then -> { relation.pluck(:score) }
  else -> { relation.spawn.to_a.each(&:attributes) }
  end
  expected = %w[find text_find].include?(shape) ? 1 : shape.end_with?("20") ? 20 : 1000
  rows = driver_work.call
  raise "wrong row count: #{shape}" unless rows.length == expected
  raise "driver/adapter mismatch: #{shape}" unless rows == adapter_work.call
  result = model_work.call
  if %w[find text_find].include?(shape)
    raise "wrong find" unless result.fetch("score") == -3_700_111
  else
    raise "wrong model row count" unless result.length == expected
  end
  { "driver" => driver_work, "adapter" => adapter_work, "model" => model_work }.each do |layer, work|
    MICRO["#{shape}_#{layer}"] = -> { work }
  end
end

warn "PDRV #{RUBY_DESCRIPTION}; #{driver}; prepared=#{prepared}; #{ActiveRecord.version}"
