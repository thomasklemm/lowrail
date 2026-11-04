require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activesupport", "lib")
require "active_support"; require "active_support/core_ext/time"
o2 = Object.new; def o2.to_int = 3; def o2.to_r = 3r
[TZInfo::Timezone.get("America/New_York"), ActiveSupport::TimeZone["America/New_York"]].each do |z|
  t = Time.utc(2026, 7, 1, 12).getlocal(z)
  [{ hour: 24, min: 30 }, { hour: 24 }, { month: 12, day: 31, hour: 23, min: 59, sec: 60 }, { min: -1 }, { sec: -1 }, { day: -1 },
   { month: 2, day: 29 }, { month: 2, day: 30 }, { month: 4, day: 31 }, { hour: o2 }, { sec: o2 }, { day: o2 }, { month: o2 }, { year: o2 },
   { sec: 59.999999999 }, { usec: 999999.9999 }, { year: 2.5 }, { day: 1.9 }, { sec: Rational(-1, 2) }, { year: "abc" }, { month: "foo" },
   { month: 11, day: 1, hour: 1, sec: 60, min: 59 }].each do |o|
    r = begin; x = t.change(o); "#{x.strftime('%F %T.%N %z')}"; rescue => e; "#{e.class}: #{e.message}"; end
    puts "#{z.class.name[0, 6]} #{o} => #{r}"
  end
end
