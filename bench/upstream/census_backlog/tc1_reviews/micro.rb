require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activesupport", "lib")
require "active_support"; require "active_support/core_ext/time"
VARIANT, CASE, N, MODE = ARGV[0], ARGV[1], Integer(ARGV[2]), ARGV[3] || "ir"

# Each variant replaces only the zone-object branch, everything else as in the commit.
module V
  def self.build(body)
    Time.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      def change(options)
        new_year   = options.fetch(:year, year)
        new_month  = options.fetch(:month, month)
        new_day    = options.fetch(:day, day)
        new_hour   = options.fetch(:hour, hour)
        new_min    = options.fetch(:min, options[:hour] ? 0 : min)
        new_sec    = options.fetch(:sec, (options[:hour] || options[:min]) ? 0 : sec)
        new_offset = options.fetch(:offset, nil)
        if new_nsec = options[:nsec]
          raise ArgumentError, "Can't change both :nsec and :usec at the same time: \#{options.inspect}" if options[:usec]
          new_usec = Rational(new_nsec, 1000)
        else
          new_usec = options.fetch(:usec, (options[:hour] || options[:min] || options[:sec]) ? 0 : Rational(nsec, 1000))
        end
        raise ArgumentError, "argument out of range" if new_usec >= 1000000
        new_sec += Rational(new_usec, 1000000) unless new_usec == 0
        if new_offset
          ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec, new_offset)
        elsif utc?
          ::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)
        elsif zone.respond_to?(:utc_to_local)
          #{body}
        elsif zone
          ::Time.local(new_sec, new_min, new_hour, new_day, new_month, new_year, nil, nil, isdst, nil)
        else
          ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec, utc_offset)
        end
      end
    RUBY
  end
end

BODIES = {
  "main" => <<~R,
    new_time = ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec, zone)
    offset_difference = new_time.utc_offset - utc_offset
    if offset_difference > 0 && (new_time_2 = new_time + offset_difference).utc_offset == utc_offset
      new_time_2
    else
      new_time
    end
  R
  "commit" => <<~R,
    new_time = (::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec) - utc_offset).getlocal(zone)
    if new_time.utc_offset == utc_offset
      new_time
    else
      ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec, zone)
    end
  R
  "localtime" => <<~R,
    new_time = (::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec) - utc_offset).localtime(zone)
    if new_time.utc_offset == utc_offset
      new_time
    else
      ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec, zone)
    end
  R
  "offset_var" => <<~R,
    offset = utc_offset
    new_time = (::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec) - offset).localtime(zone)
    if new_time.utc_offset == offset
      new_time
    else
      ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec, zone)
    end
  R
}
V.build(BODIES.fetch(VARIANT)) unless VARIANT == "none"

U = Time.utc(2026, 1, 15, 11, 0, 0, Rational(1234567, 1000))
AS_T = U.getlocal(ActiveSupport::TimeZone["Europe/Berlin"])
TZ_T = U.getlocal(TZInfo::Timezone.get("Europe/Berlin"))
CASES = {
  "as_nsec" => -> { AS_T.change(nsec: 1234000) },
  "tz_nsec" => -> { TZ_T.change(nsec: 1234000) },
  "as_cross" => -> { AS_T.change(month: 7) },   # offset differs -> fallback path
  "tz_cross" => -> { TZ_T.change(month: 7) },
  "as_bod" => -> { AS_T.beginning_of_day },
}
f = CASES.fetch(CASE)
if MODE == "check"
  puts BODIES.keys.map { |k| V.build(BODIES[k]); r = f.(); "#{k}: #{r.strftime('%F %T.%N %z')} #{r.zone.class}" }
  exit
end
3000.times { f.() }
GC.start; GC.disable
case MODE
when "ir" then [0].cycle(1) { N.times { f.() } }
when "obj" then b = GC.stat(:total_allocated_objects); N.times { f.() }; puts (GC.stat(:total_allocated_objects) - b).fdiv(N)
end
