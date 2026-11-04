require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activesupport", "lib")
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activemodel", "lib")
require "active_support"; require "active_support/core_ext/time"
require "active_model"

def fmt(v)
  case v
  when Time then "#{v.strftime('%F %T.%N %z')} sub=#{v.subsec.inspect} #{v.class} zone=#{v.zone.class}:#{v.zone.respond_to?(:name) ? v.zone.name : v.zone.inspect} frozen=#{v.frozen?}"
  else v.inspect
  end
end
def run(label)
  r = begin; fmt(yield); rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{label} => #{r}"
end

class OnlyU2L # implements only utc_to_local
  def utc_to_local(t) = t + 3 * 3600
  def inspect = "OnlyU2L"
end
class CountingZone
  attr_reader :calls
  def initialize(z) = (@z = z; @calls = Hash.new(0))
  def utc_to_local(t) = (@calls[:u2l] += 1; @z.utc_to_local(t))
  def local_to_utc(t) = (@calls[:l2u] += 1; @z.local_to_utc(t))
  def inspect = "Counting"
end
class RaisingU2L
  def utc_to_local(t) = raise("u2l boom")
  def local_to_utc(t) = t - 3600
  def inspect = "RaisingU2L"
end
class SubTime < Time; end

zones = {
  "tz:Amsterdam" => TZInfo::Timezone.get("Europe/Amsterdam"),
  "as:Amsterdam" => ActiveSupport::TimeZone["Europe/Amsterdam"],
  "tz:Monrovia" => TZInfo::Timezone.get("Africa/Monrovia"),
  "as:Monrovia" => ActiveSupport::TimeZone["Africa/Monrovia"],
  "tz:Apia" => TZInfo::Timezone.get("Pacific/Apia"),
  "as:Apia" => ActiveSupport::TimeZone["Pacific/Apia"],
  "tz:NY" => TZInfo::Timezone.get("America/New_York"),
  "as:NY" => ActiveSupport::TimeZone["America/New_York"],
  "tz:LordHowe" => TZInfo::Timezone.get("Australia/Lord_Howe"),
  "tz:Dublin" => TZInfo::Timezone.get("Europe/Dublin"),
  "as:Dublin" => ActiveSupport::TimeZone["Europe/Dublin"],
  "tz:Casablanca" => TZInfo::Timezone.get("Africa/Casablanca"),
  "tz:Troll" => TZInfo::Timezone.get("Antarctica/Troll"),
  "tz:Kiritimati" => TZInfo::Timezone.get("Pacific/Kiritimati"),
}

instants = [
  Time.utc(1880, 6, 1, 12), Time.utc(1937, 6, 30, 22, 30), Time.utc(1937, 7, 1, 0, 30), Time.utc(1971, 12, 31, 23), Time.utc(1972, 1, 7, 12),
  Time.utc(2011, 12, 29, 9, 30), Time.utc(2011, 12, 30, 10, 30), Time.utc(2011, 12, 31, 12),
  Time.utc(2026, 3, 8, 6, 30), Time.utc(2026, 3, 8, 7, 30), Time.utc(2026, 11, 1, 5, 30), Time.utc(2026, 11, 1, 6, 30),
  Time.utc(2026, 10, 25, 0, 30), Time.utc(2026, 10, 25, 1, 30), Time.utc(2026, 12, 31, 23, 59, 59) + Rational(999999999, 10**9),
  Time.utc(2026, 4, 5, 15, 30), Time.utc(2026, 4, 5, 14, 45), Time.utc(2026, 2, 15, 1), Time.utc(2026, 3, 22, 1, 30),
]
opts = [
  {}, { nsec: 0 }, { nsec: Rational(1, 3) }, { usec: Rational(1, 3) }, { usec: 1.5 }, { sec: 1.5 }, { sec: Rational(7, 3) },
  { sec: 59 }, { sec: 60 }, { min: 60 }, { hour: 24 }, { hour: 25 }, { day: 31 }, { day: 30 }, { day: 29, month: 2 }, { day: 31, month: 2 },
  { day: 32 }, { day: 0 }, { month: 13 }, { month: 0 }, { year: 0 }, { year: -1 }, { year: 10_000 }, { year: 2**40 },
  { year: "2026" }, { month: "oct" }, { day: "25" }, { hour: "2" }, { sec: "1.5" }, { hour: 2.5 }, { year: nil }, { hour: nil },
  { offset: "+05:00" }, { offset: 3600 }, { offset: "UTC" },
  { hour: 1 }, { hour: 2 }, { hour: 3 }, { day: 30, month: 12, year: 2011 }, { day: 29, month: 12, year: 2011 },
  { year: 1880 }, { year: 1937, month: 7, day: 1, hour: 0, min: 10 }, { year: 1972, month: 1, day: 7 }, { year: 1971, month: 12, day: 31 },
  { year: 2026, month: 11, day: 1, hour: 1, min: 30 }, { year: 2026, month: 3, day: 8, hour: 2, min: 30 }, { year: 2026, month: 10, day: 25, hour: 1 },
  { year: 2026, month: 10, day: 25, hour: 2 },
]
zones.each do |zn, zone|
  instants.each do |u|
    t = (u.getlocal(zone) rescue next)
    opts.each { |o| run("#{zn}|#{fmt(t)}|#{o}") { t.change(o) } }
    %i[beginning_of_day end_of_day middle_of_day beginning_of_hour end_of_hour beginning_of_minute end_of_minute
       beginning_of_month end_of_month beginning_of_year end_of_year beginning_of_quarter end_of_quarter].each do |m|
      run("#{zn}|#{fmt(t)}|#{m}") { t.public_send(m) }
    end
    [{ days: 1 }, { days: -1 }, { months: 1 }, { hours: 1 }, { days: 0.5 }, { years: -1 }, {}].each do |o|
      run("#{zn}|#{fmt(t)}|advance #{o}") { t.advance(o) }
    end
    run("#{zn}|#{fmt(t)}|am-precision0") { ActiveModel::Type::DateTime.new(precision: 0).cast(t + Rational(123456789, 10**9)) }
    run("#{zn}|#{fmt(t)}|am-precision3") { ActiveModel::Type::DateTime.new(precision: 3).cast(t + Rational(123456789, 10**9)) }
  end
end

# minimal / odd zone objects
[OnlyU2L.new, RaisingU2L.new].each do |z|
  t = Time.utc(2026, 1, 1, 12).getlocal(z) rescue (puts "#{z.inspect} getlocal failed"; next)
  [{}, { hour: 1 }, { day: 31, month: 4 }, { nsec: 5 }].each { |o| run("#{z.inspect}|#{o}") { t.change(o) } }
end
c = CountingZone.new(TZInfo::Timezone.get("Europe/Berlin"))
t = Time.utc(2026, 7, 1, 12).getlocal(c)
c.calls.clear
run("counting change(hour: 1)") { t.change(hour: 1) }
puts "counting calls #{c.calls.sort.to_h}"
c.calls.clear
run("counting change(hour: 2, day: 29, month: 3)") { t.change(hour: 2, day: 29, month: 3) }
puts "counting calls #{c.calls.sort.to_h}"

# receiver variations
z = ActiveSupport::TimeZone["Europe/Berlin"]
sub = SubTime.utc(2026, 10, 25, 0, 30).getlocal(z)
run("subclass class") { sub.class }
run("subclass change") { sub.change(min: 0) }
fr = Time.utc(2026, 10, 25, 0, 30).getlocal(z).freeze
run("frozen change") { fr.change(min: 0) }
s = Time.utc(2026, 10, 25, 0, 30).getlocal(z)
def s.utc_offset = 3600
run("singleton utc_offset=3600 change(min:0)") { s.change(min: 0) }
s2 = Time.utc(2026, 7, 1, 0, 30).getlocal(z)
def s2.zone = TZInfo::Timezone.get("Asia/Tokyo")
run("singleton zone=Tokyo change(min:0)") { s2.change(min: 0) }
s3 = Time.utc(2026, 7, 1, 0, 30).getlocal(z)
def s3.hour = 5
run("singleton hour=5 change(min:0)") { s3.change(min: 0) }
puts "TZ=#{ENV['TZ']}"
