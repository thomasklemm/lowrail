require "bundler/setup"
require "active_support"
require "active_support/core_ext/time"
require "active_support/core_ext/numeric/time"
CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
CHI = ActiveSupport::TimeZone["Central Time (US & Canada)"]
Time.zone = CHI
NOV = CHI.local(2026, 11, 5, 12, 0, 0)    # CST; 70 days back is CDT
JUN = CHI.local(2027, 6, 28, 12, 0, 0)    # CDT; 70 days back is CDT
NOV1 = CHI.local(2026, 11, 1, 12, 0, 0)   # CST, the day clocks went back
UTCZ = ActiveSupport::TimeZone["UTC"].local(2026, 11, 5, 12)
TOKYO = ActiveSupport::TimeZone["Tokyo"].local(2026, 11, 5, 12)
LOCAL = Time.utc(2026, 8, 27, 12)          # wall clock for the tzinfo calls
TZ = CHI.tzinfo
INFO = TZ.send(:info)
TS = TZInfo::Timestamp.for(LOCAL, :ignore)
FRESH_U = Time.utc(2026, 11, 5, 18)
P1 = TZ.periods_for_local(LOCAL).first
P2 = TZ.periods_for_local(LOCAL).first
PA = [P2]
P_WINTER = TZ.periods_for_local(Time.utc(2026, 12, 1, 12)).first
PW = [P_WINTER]
T1 = P1.start_transition
CASES = {
  "tz_period_eq" => -> { PA.include?(P1) },
  "tz_period_ne" => -> { PW.include?(P1) },
  "tz_transition_eq" => -> { T1 == T1 },
  "change_same" => -> { JUN.change(hour: 3) },
  "fresh_bod" => -> { ActiveSupport::TimeWithZone.new(FRESH_U, CHI).beginning_of_day },
  "fresh_ago" => -> { 70.days.ago(ActiveSupport::TimeWithZone.new(FRESH_U, CHI)) },
  "fresh_new" => -> { ActiveSupport::TimeWithZone.new(FRESH_U, CHI) },
  "ago_same" => -> { 70.days.ago(JUN) },
  "ago_cross" => -> { 70.days.ago(NOV) },
  "day_cross" => -> { 1.day.ago(NOV1) },
  "bod_same" => -> { NOV.beginning_of_day },
  "bod_cross" => -> { NOV1.beginning_of_day },
  "change_cross" => -> { NOV.change(month: 8) },
  "utc_ago" => -> { 70.days.ago(UTCZ) },
  "tokyo_ago" => -> { 70.days.ago(TOKYO) },
  "tz_periods_for_local" => -> { TZ.periods_for_local(LOCAL) },
  "tz_period_for_local" => -> { TZ.period_for_local(LOCAL) },
  "as_period_for_local" => -> { CHI.period_for_local(LOCAL) },
  "tz_timestamp_for" => -> { TZInfo::Timestamp.for(LOCAL, :ignore) },
  "tz_info_periods_for_local" => -> { INFO.periods_for_local(TS) },
  "tz_period_for_utc" => -> { TZ.period_for_utc(LOCAL) },
  "tz_utc_to_local" => -> { TZ.utc_to_local(LOCAL) },
  "tz_transitions" => -> { INFO.instance_variable_get(:@transitions).size },
}
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 3000).to_i.times { f.() }
GC.start; GC.disable
case MODE
when "ir" then [0].cycle(1) { N.times { f.() } }
when "obj" then b = GC.stat(:total_allocated_objects); N.times { f.() }; puts (GC.stat(:total_allocated_objects) - b).fdiv(N)
when "show" then puts f.().inspect
else t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond); N.times { f.() }; puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
