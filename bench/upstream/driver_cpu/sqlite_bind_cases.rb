# frozen_string_literal: true

load File.join(__dir__, "cases.rb")
connection = ActiveRecord::Base.lease_connection
ids = [37, 2, 511, 1000, 19, 201, 87, 66, 9, 730, 46, 301, 802, 55, 144, 250, 600, 999, 5, 74]
relation = DriverRow.where(name: ids.map { "row-#{_1}-é" }).order(:id)
query = relation.select(:id)
sql, binds, = connection.send(:to_sql_and_binds, query.arel)
casted = connection.send(:type_casted_binds, binds)
raw = connection.raw_connection
prepared = ENV.fetch("PREPARED", "1") == "1"
statement = raw.prepare(sql) if prepared
driver = -> {
  stmt = prepared ? statement.reset! : raw.prepare(sql)
  stmt.bind_params(casted)
  rows = stmt.to_a
  stmt.columns
  stmt.types
  stmt.close unless prepared
  rows
}
adapter = -> { connection.select_all(query.arel).rows }
model = -> { relation.pluck(:id) }
expected = ids.sort
raise "wrong batch driver values" unless driver.call.flatten == expected
raise "wrong batch adapter values" unless adapter.call.flatten == expected
raise "wrong batch pluck values" unless model.call == expected
MICRO["bind20_driver"] = -> { driver }
MICRO["bind20_adapter"] = -> { adapter }
MICRO["bind20_model"] = -> { model }
