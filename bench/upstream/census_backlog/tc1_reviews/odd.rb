require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activesupport", "lib")
require "active_support"; require "active_support/core_ext/time"; require "bigdecimal"
def fmt(v) = v.is_a?(Time) ? "#{v.strftime('%F %T.%N %z')} sub=#{v.subsec.inspect} #{v.class} zone=#{v.zone.inspect[0,40]}" : v.inspect
def run(l) = puts("#{l} => #{begin; fmt(yield); rescue Exception => e; "#{e.class}: #{e.message[0,80]}"; end}")
class L2UOnly # utc_to_local raises; local_to_utc fine. Receiver built with Time.new (only local_to_utc)
  def local_to_utc(t) = t - 3600
  def utc_to_local(t) = raise("u2l not supported")
  def inspect = "L2UOnly"
end
class Flip # utc_to_local alternates +1h/+2h per call; local_to_utc -1h
  def initialize = @n = 0
  def utc_to_local(t) = t + 3600 * (1 + (@n += 1) % 2)
  def local_to_utc(t) = t - 3600
  def inspect = "Flip"
end
class Lies # local_to_utc disagrees with utc_to_local (half-implemented DST zone)
  def utc_to_local(t) = t + (t.month.between?(4, 9) ? 7200 : 3600)
  def local_to_utc(t) = t - 3600
  def inspect = "Lies"
end
class TWO # utc_to_local returns TZInfo::TimeWithOffset
  Z = TZInfo::Timezone.get("Europe/Berlin")
  def utc_to_local(t) = Z.utc_to_local(t)
  def local_to_utc(t) = Z.local_to_utc(t, true)
  def inspect = "TWO"
end
class Frac # half-second offset
  def utc_to_local(t) = t + Rational(7201, 2)
  def local_to_utc(t) = t - Rational(7201, 2)
  def inspect = "Frac"
end
t = Time.new(2026, 1, 1, 12, 0, 0, L2UOnly.new)
run("L2UOnly recv") { t }
run("L2UOnly change(hour: 3)") { t.change(hour: 3) }
run("L2UOnly change(nsec: 0)") { t.change(nsec: 0) }
f = Flip.new; t = Time.new(2026, 1, 1, 12, 0, 0, f)
run("Flip recv") { t }
3.times { |i| run("Flip change(min: 5) ##{i}") { t.change(min: 5) } }
lz = Lies.new
[Time.new(2026, 6, 1, 12, 0, 0, lz), Time.utc(2026, 6, 1, 12).getlocal(lz), Time.utc(2026, 1, 1, 12).getlocal(lz)].each_with_index do |r, i|
  run("Lies recv#{i}") { r }
  run("Lies#{i} change(min: 5)") { r.change(min: 5) }
  run("Lies#{i} change(month: 1)") { r.change(month: 1) }
  run("Lies#{i} change(month: 6)") { r.change(month: 6) }
end
t = Time.utc(2026, 10, 25, 0, 30).getlocal(TWO.new)
run("TWO change(min:0)") { t.change(min: 0) }
t = Time.utc(2026, 10, 25, 1, 30).getlocal(TWO.new)
run("TWO2 change(min:0)") { t.change(min: 0) }
t = Time.utc(2026, 1, 1, 12).getlocal(Frac.new)
run("Frac recv") { t }
run("Frac change(min:0)") { t.change(min: 0) }
z = ActiveSupport::TimeZone["Europe/Berlin"]
base = Time.utc(2026, 10, 25, 0, 30).getlocal(z)
[0.1, 1.000001, 59.999999999, BigDecimal("1.123456789123"), Rational(1, 7), 1e-10].each do |s|
  run("sec #{s.inspect}") { base.change(sec: s) }
  run("usec #{s.inspect}") { base.change(usec: s) }
end
run("year -1") { base.change(year: -1) }
run("year -4713") { base.change(year: -4713) }
run("Time.at in: AS") { Time.at(1792881000, in: z).change(min: 0) }
run("Time.at in: AS float") { Time.at(1792881000.25, in: z).change(sec: 0) }
run("Time.new in: AS") { Time.new(2026, 10, 25, 2, 30, 0, in: z).change(sec: 5) }
m = Marshal.load(Marshal.dump(base))
run("marshal zone") { m.zone.class }
run("marshal change") { m.change(min: 0) }
run("localtime(zone)") { Time.utc(2026, 10, 25, 1, 30).localtime(z).change(min: 0) }
class SubT < Time; end
run("subclass") { SubT.at(1792881000, in: z).change(min: 0) }
run("round(0)") { (base + Rational(1, 3)).round }
run("floor/ceil") { [(base + 0.4).floor.to_s, (base + 0.4).ceil.to_s] }
Time.zone = "Europe/Berlin"
run("Time.zone set, getlocal(Time.zone)") { Time.utc(2026, 10, 25, 1, 30).getlocal(Time.zone).change(nsec: 0) }
res = 8.times.map { |i| Thread.new { 500.times.map { Time.utc(2026, 10, 25, 0, 30 + i).getlocal(z).change(sec: 0).utc_offset }.uniq } }.map(&:value)
run("threads") { res }
