require "bundler/setup"
%w[activesupport activemodel].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "active_support"; require "active_support/core_ext/time"; require "active_model"
tz = TZInfo::Timezone.get("Europe/Berlin")
as = ActiveSupport::TimeZone["Europe/Berlin"]
utc = Time.utc(2026, 10, 25, 0, 30, 0, Rational(1234567, 1000)) # 02:30:00.001234567 +02:00 (first occurrence)
utc2 = utc + 3600                                                 # 02:30 +01:00 (second)
def show(label) = (v = yield; puts "#{label}: #{v.inspect} #{v.utc_offset rescue ''}") rescue puts("#{label}: #{$!.class}: #{$!.message[0, 70]}")
type = ActiveModel::Type::DateTime.new(precision: 6)
[[:first, utc], [:second, utc2]].each do |name, u|
  t_tz = u.getlocal(tz); t_as = u.getlocal(as); t_two = tz.to_local(u)
  show("#{name} tz getlocal          ") { t_tz }
  show("#{name} tz change(nsec:)     ") { t_tz.change(nsec: 1234000) }
  show("#{name} tz change(hour: 2)   ") { t_tz.change(hour: 2) }
  show("#{name} tz cast precision 6  ") { type.cast(t_tz) }
  show("#{name} AS zone change(nsec:)") { t_as.change(nsec: 1234000) }
  show("#{name} TimeWithOffset change") { t_two.change(nsec: 1234000) }
  show("#{name} TimeWithOffset cast  ") { type.cast(t_two) }
end
