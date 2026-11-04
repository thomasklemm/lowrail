require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV.fetch("RAILS"), "activesupport/lib")
require "active_support"
require "active_support/core_ext/time"
tz = TZInfo::Timezone.get("Europe/Berlin")
# 2026-10-25 02:30 happens twice in Berlin (clocks go back at 03:00 CEST)
t = Time.at(Time.utc(2026, 10, 25, 0, 30, 0).to_r + Rational(1234567, 10**9)).getlocal(tz)  # first 02:30, CEST
u = Time.at(Time.utc(2026, 10, 25, 1, 30, 0).to_r + Rational(1234567, 10**9)).getlocal(tz)  # second 02:30, CET
[t, u].each do |x|
  f = x.floor(6)
  c = begin; x.change(nsec: x.nsec / 1000 * 1000); rescue => e; e; end
  puts "#{x.inspect} dst?=#{x.dst?}"
  puts "  floor(6):       #{f.inspect} dst?=#{f.dst?} utc_offset=#{f.utc_offset}"
  puts "  change(nsec:):  #{c.is_a?(Exception) ? "#{c.class}: #{c.message}" : "#{c.inspect} dst?=#{c.dst?} utc_offset=#{c.utc_offset}"}"
end
