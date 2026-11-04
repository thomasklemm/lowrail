require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "group_by_test")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table :bookings, force: true }
class Booking < ActiveRecord::Base; end
[["SELECT DATE :d AS d", { d: Date.new(2026, 1, 2) }], ["SELECT (:x IS NULL) AS d", { x: nil }]].each do |sql, h|
  print sql, " => "
  begin; p Booking.find_by_sql([sql, h]).first.d; rescue => e; puts "#{e.class}: #{e.message.lines.first.strip}"; end
end
