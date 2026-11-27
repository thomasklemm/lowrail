# Flow's RunnerProtocolConformanceTest: Time.iso8601 of an impossible date. time 0.4.2 (Ruby 4.0.9) builds it from
# its parts and rolls it over to March 2; time 0.5.0 (master) calls Time.new(string), which keeps Feb 30 in the
# broken-down fields of a Time whose instant is March 2.
require "time"
t = Time.iso8601("2026-02-30T00:00:00Z")
p [Time::VERSION, t.to_i == Time.utc(2026, 3, 2).to_i, t.mon, t.day, t.iso8601]
raise "Feb 30 kept: #{t.iso8601}" unless [t.mon, t.day] == [3, 2]
puts "ok"
