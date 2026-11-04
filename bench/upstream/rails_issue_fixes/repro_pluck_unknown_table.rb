require "logger"
require "active_record"
require "logger"
adapter = ENV.fetch("ADAPTER", "postgresql")
if adapter == "postgresql"
  ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "group_by_test")
else
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
end
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:rooms, force: true) { |t| t.date :day; t.boolean :open }
  create_table(:bookings, force: true) { |t| t.integer :room_id }
end
class Room < ActiveRecord::Base; end
class Booking < ActiveRecord::Base; end
room = Room.create!(day: "2020-01-01", open: true); Booking.create!(room_id: room.id)
rel = Booking.joins("JOIN (SELECT id AS rid, day AS d, open AS o FROM rooms) s ON s.rid = bookings.room_id")
out = { version: ActiveRecord.version.to_s, adapter: adapter,
  pluck: rel.pluck("s.d", "s.o"), pick: rel.pick("s.d"), pluck_one: rel.pluck("s.d"),
  group: rel.group("s.d").count.keys }
if adapter == "postgresql"
  r = Booking.joins("JOIN (SELECT tsrange(timestamp '2020-01-01', timestamp '2020-01-02') AS range) ranges ON TRUE")
  out[:pluck_range] = r.pluck("ranges.range").map(&:class)
end
p out
