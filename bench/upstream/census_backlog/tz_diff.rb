# Differential for Time#change on Times whose zone is an object (TC-1). One line per case; compare main and branch output with tz_compare.py.
require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activesupport", "lib")
require "active_support"; require "active_support/core_ext/time"
class MinimalZone # fixed +03:00, the minimal protocol Ruby needs
  def initialize(name) = @name = name
  def utc_to_local(t) = t + 3 * 3600
  def local_to_utc(t) = t - 3 * 3600
  def abbr(*) = @name
  def inspect = "MinimalZone"
end
names = %w[Europe/Berlin America/New_York Australia/Sydney Australia/Lord_Howe Pacific/Apia America/Sao_Paulo Asia/Kolkata Europe/Dublin UTC]
zones = names.flat_map { |n| [["tz:#{n}", TZInfo::Timezone.get(n)], ["as:#{n}", ActiveSupport::TimeZone[n]]] } + [["minimal", MinimalZone.new("M")]]
opts = [{ nsec: 1234000 }, { usec: 5 }, { sec: 0 }, { min: 30 }, { hour: 2 }, { hour: 1 }, { hour: 3 }, { day: 1 }, { day: 31 },
        { month: 3 }, { month: 10 }, { month: 11 }, { year: 2011 }, { year: 1890 }, { day: 30, month: 12, year: 2011 }, {}, { nsec: 999999999 }, { offset: "+05:00" }]
fmt = ->(v) { v.is_a?(Time) ? "#{v.strftime('%F %T.%N %z')} #{v.class} zone=#{v.zone.equal?(nil) ? 'nil' : v.zone.class}" : v.inspect }
cases = 0
zones.each do |zn, zone|
  # instants every 15 minutes across the two 2026 DST changes of each hemisphere, plus fixed instants
  starts = [Time.utc(2026, 3, 28, 12), Time.utc(2026, 4, 4, 10), Time.utc(2026, 10, 3, 10), Time.utc(2026, 10, 24, 12), Time.utc(2026, 11, 1, 0), Time.utc(2011, 12, 29, 0)]
  instants = starts.flat_map { |s| (0...(30 * 4)).map { s + _1 * 900 + Rational(1234567, 10**9) } } + [Time.utc(1890, 6, 1, 12), Time.utc(2026, 7, 1)]
  instants.each do |u|
    t = (u.getlocal(zone) rescue next)
    opts.each do |o|
      r = begin; fmt.(t.change(o)); rescue => e; "#{e.class}"; end
      a = begin; fmt.(t.advance(days: 1)); rescue => e; "#{e.class}"; end if o.empty?
      puts "#{zn}|#{fmt.(t)}|#{o}|#{r}#{a && "|adv #{a}"}"
      cases += 1
    end
  end
end
warn "cases #{cases}"
