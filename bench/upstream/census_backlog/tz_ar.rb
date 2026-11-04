require "bundler/setup"
%w[activesupport activemodel activerecord].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:events) { |t| t.datetime :at, precision: 6 } }
class Event < ActiveRecord::Base; end
tz = TZInfo::Timezone.get("Europe/Berlin")
u = Time.utc(2026, 1, 15, 11, 0, 0, Rational(1234567, 1000))
two = tz.to_local(u)
puts "TimeWithOffset #{two.inspect} class=#{two.class} zone=#{two.zone.inspect}"
puts "change(nsec:)  #{two.change(nsec: 1234000).inspect}  same instant? #{two.change(nsec: 1234000).to_i == u.to_i}"
puts "change(hour:9) #{two.change(hour: 9).inspect}"
puts "beginning_of_day #{two.beginning_of_day.inspect}"
e = Event.create!(at: two)
puts "AR stored      #{e.reload.at.inspect}  same instant? #{e.at.to_i == u.to_i}"
e2 = Event.create!(at: tz.now); puts "AR tz.now     #{(e2.reload.at - Time.now).round}s from now"
ActiveSupport::TimeZone["Europe/Berlin"].then { |z| r = z.utc_to_local(u); puts "AS TimeZone#utc_to_local -> #{r.class} #{r.change(nsec: 0).inspect}" }
