# frozen_string_literal: true

load File.join(__dir__, "cases.rb")
connection = ActiveRecord::Base.lease_connection
raw = connection.raw_connection
%w[null empty].each do |kind|
  expression = kind == "null" ? "NULL::text" : "''::text"
  columns = Array.new(7, expression).join(", ")
  sql = "SELECT #{columns} FROM driver_rows ORDER BY id"
  driver = -> {
    result = raw.exec_params(sql)
    rows = result.values
    result.fields
    result.clear
    rows
  }
  model = -> { DriverRow.order(:id).pluck(*Array.new(7) { Arel.sql(expression) }) }
  expected = Array.new(1000) { Array.new(7, kind == "null" ? nil : "") }
  raise "wrong #{kind} driver values" unless driver.call == expected
  raise "wrong #{kind} pluck values" unless model.call == expected
  MICRO["#{kind}_driver"] = -> { driver }
  MICRO["#{kind}_model"] = -> { model }
end
