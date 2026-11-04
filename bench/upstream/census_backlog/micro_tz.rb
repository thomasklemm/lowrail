require "bundler/setup"
%w[activesupport activemodel].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "active_support"; require "active_support/core_ext/time"; require "active_model"
CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
U = Time.utc(2026, 1, 15, 11, 0, 0, Rational(1234567, 1000))
AS_T = U.getlocal(ActiveSupport::TimeZone["Europe/Berlin"])
TZ_T = U.getlocal(TZInfo::Timezone.get("Europe/Berlin"))
AS_SUMMER = Time.utc(2026, 7, 1, 12).getlocal(ActiveSupport::TimeZone["Europe/Berlin"])
TWZ = U.in_time_zone("Europe/Berlin")
LOCAL = U.getlocal
TYPE = ActiveModel::Type::DateTime.new(precision: 6)
CASES = {
  "as_zone_change" => -> { AS_T.change(nsec: 1234000) },
  "tz_zone_change" => -> { TZ_T.change(nsec: 1234000) },
  "as_zone_cast" => -> { TYPE.cast(AS_T) },
  "twz_cast" => -> { TYPE.cast(TWZ) },
  "as_zone_month" => -> { AS_SUMMER.change(month: 1) },
  "local_change" => -> { LOCAL.change(hour: 0) },
}
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 3000).to_i.times { f.() }
GC.start; GC.disable
case MODE
when "ir" then [0].cycle(1) { N.times { f.() } }
when "obj" then b = GC.stat(:total_allocated_objects); N.times { f.() }; puts (GC.stat(:total_allocated_objects) - b).fdiv(N)
else t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond); N.times { f.() }; puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
