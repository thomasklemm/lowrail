# Differential for apply_seconds_precision: main's TimeValue vs the candidate's, same process.
# ruby diff_dtp.rb MAIN_TIME_VALUE_RB CAND_TIME_VALUE_RB  (run with bundle exec from a worktree; RAILS=$PWD)
require "bundler/setup"
require_relative "setup"
require "active_record/type/time" rescue nil
main_src, cand_src = ARGV.map { File.read(_1) }
mod_src = ->(src, name) { src.sub("module TimeValue", "module #{name}") }
eval(mod_src.(main_src, "TimeValueMain"), TOPLEVEL_BINDING)
eval(mod_src.(cand_src, "TimeValueCand"), TOPLEVEL_BINDING)
H = ActiveModel::Type::Helpers
class Prec
  def initialize(mod, precision) = (extend(mod); @precision = precision)
  attr_reader :precision
end

def describe(v)
  case v
  when ActiveSupport::TimeWithZone
    [:twz, v.utc.to_r, v.time.to_r, v.time_zone.name, v.utc_offset, v.zone, v.dst?, v.period.utc_total_offset, v.inspect, v.frozen?]
  when Time
    [v.class, v.to_r, v.utc_offset, v.zone.is_a?(String) || v.zone.nil? ? v.zone : v.zone.class, v.utc?, v.dst?, v.inspect, v.frozen?, v.singleton_methods.sort, (class << v; ancestors; end).take_while { _1 != v.class }.map(&:to_s).reject { _1.start_with?("#<Class") }]
  when DateTime
    [:dt, v.ajd, v.offset, v.inspect]
  else
    [v.class, v.inspect]
  end
end

def outcome(mod, prec, v)
  r = Prec.new(mod, prec).apply_seconds_precision(v)
  [:ok, r.equal?(v), describe(r)]
rescue Exception => e
  [:raise, e.class, e.message]
end

$n = 0; $diffs = []
def check(v)
  [nil, 0, 1, 3, 6, 9].each do |p|
    $n += 1
    a = outcome(H::TimeValueMain, p, v)
    b = outcome(H::TimeValueCand, p, v)
    $diffs << [p, v.inspect, a, b] if a != b
  end
end

zones = %w[UTC America/New_York Europe/London Europe/Tallinn Australia/Lord_Howe Asia/Kathmandu America/St_Johns Pacific/Chatham Africa/Monrovia Europe/Amsterdam America/Caracas]
fracs = [0, Rational(1, 10**9), Rational(999, 10**9), Rational(1000, 10**9), Rational(123_456_789, 10**9), Rational(999_999_999, 10**9), Rational(1, 3), 0.1, 0.123456789, Rational(1, 10**12), Rational(123_456_000_001, 10**12)]
bases = [0, 1, -1, -86_400 * 365 * 100 - 7, 1_700_000_000, 2_000_000_000, -2_208_988_800, 253_402_300_799]
# DST transitions of each zone around 2026 and historic LMT-era instants
transitions = zones.flat_map do |z|
  tz = TZInfo::Timezone.get(z)
  tz.transitions_up_to(Time.utc(2027), Time.utc(2025)).flat_map { |t| [t.at.to_i - 1, t.at.to_i, t.at.to_i + 1, t.at.to_i - 3601, t.at.to_i + 3599] } +
    [Time.utc(1850, 6, 1).to_i, Time.utc(1900, 1, 1).to_i + 13]
end
(bases + transitions).each do |s|
  fracs.each do |f|
    t = Time.at(s + f)
    check(t.utc)
    check(t.getlocal)
    check(t.getlocal("+05:45"))
    check(t.getlocal("-03:30"))
    zones.each do |z|
      tz = TZInfo::Timezone.get(z)
      check(t.getlocal(tz)) rescue nil
      check(t.in_time_zone(z))
    end
    check(DateTime.new(2026, 3, 29, 1, 30, 15 + f.to_r, "+02:00")) if f.is_a?(Rational)
  end
end
# frozen, subclass, singleton, AR's delegator
check(Time.now.freeze)
class MyTime < Time; end
check(MyTime.now)
t = Time.now; def t.extra = 1; check(t)
check(Time.now.extend(Comparable))
check(ActiveRecord::Type::Time::Value.new(Time.now)) if defined?(ActiveRecord::Type::Time::Value)
check(Time.zone.now.freeze)
check(Date.today); check(nil); check("2026-01-01 10:00:00.123456789"); check(1.5)
# Time with a mocked zone object
rng = Random.new(41231)
50_000.times do
  s = rng.rand(-3_000_000_000..4_000_000_000) + Rational(rng.rand(10**9), 10**9)
  z = zones.sample(random: rng)
  check(Time.at(s).in_time_zone(z)); check(Time.at(s).utc); check(Time.at(s).getlocal(TZInfo::Timezone.get(z)))
end
%w[UTC America/Los_Angeles Asia/Tokyo].each do |envtz|
  ENV["TZ"] = envtz
  [1_700_000_000, 1_741_510_800, 1_762_070_400].each { |s| fracs.each { |f| check(Time.at(s + f)) } }
end
puts "checked #{$n} (value, precision) pairs; differences: #{$diffs.size}"
$diffs.first(8).each { pp _1 }
cats = $diffs.group_by do |p, s, a, b|
  if a[0] == :ok && b[0] == :ok
    [:ok, a[2][0], a[2][3], (0...a[2].size).reject { a[2][_1] == b[2][_1] }]
  else
    [a[0], b[0], a[1], b[1]]
  end
end
cats.each { |k, v| puts "#{v.size} #{k.inspect}" }
