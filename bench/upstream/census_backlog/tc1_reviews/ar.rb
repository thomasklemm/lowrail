require "bundler/setup"
%w[activesupport activemodel activerecord].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:events) { |t| t.datetime :p0, precision: 0; t.datetime :p3, precision: 3; t.datetime :p6, precision: 6; t.datetime :pn, precision: nil } }
class Event < ActiveRecord::Base; end
fmt = ->(v) { v.respond_to?(:strftime) ? "#{v.strftime('%F %T.%N %z')} #{v.class}" : v.inspect }
zones = { "as" => ActiveSupport::TimeZone["Europe/Berlin"], "tz" => TZInfo::Timezone.get("Europe/Berlin"), "asdub" => ActiveSupport::TimeZone["Europe/Dublin"], "tzny" => TZInfo::Timezone.get("America/New_York") }
utcs = [Time.utc(2026, 10, 25, 0, 30, Rational(123456789, 10**9)), Time.utc(2026, 10, 25, 1, 30, Rational(123456789, 10**9)), Time.utc(2026, 11, 1, 5, 30, Rational(5, 7)), Time.utc(2026, 11, 1, 6, 30, Rational(5, 7)), Time.utc(2026, 7, 1, 12, 0, 0.25)]
[[true, :utc], [false, :utc], [true, :local], [false, :local]].each do |tza, dtz|
  ActiveRecord::Base.time_zone_aware_attributes = tza
  ActiveRecord.default_timezone = dtz
  Event.reset_column_information
  [nil, "Europe/Berlin", "America/New_York"].each do |tzname|
    Time.zone = tzname
    zones.each do |zn, z|
      utcs.each do |u|
        v = u.getlocal(z)
        r = begin
          e = Event.new(p0: v, p3: v, p6: v, pn: v)
          before = [e.p0, e.p3, e.p6, e.pn].map(&fmt)
          e.save!
          after = e.reload.then { [_1.p0, _1.p3, _1.p6, _1.pn].map(&fmt) }
          "set=#{before.join(',')} db=#{after.join(',')}"
        rescue => ex then "#{ex.class}: #{ex.message[0, 60]}"
        end
        puts "tza=#{tza} dtz=#{dtz} Time.zone=#{tzname.inspect} #{zn} #{fmt.(v)} #{r}"
      end
    end
  end
end
