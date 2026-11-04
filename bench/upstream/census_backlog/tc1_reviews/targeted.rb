require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activesupport", "lib")
require "active_support"; require "active_support/core_ext/time"
def show(label) = puts("#{label}: #{begin; r = yield; r.is_a?(Time) ? "#{r.strftime('%F %T.%N %z')} (#{r.to_i - 0})" : r.inspect; rescue => e; "#{e.class}: #{e.message}"; end}")

%w[Australia/Lord_Howe Pacific/Apia Pacific/Kiritimati].each do |n|
  [TZInfo::Timezone.get(n), ActiveSupport::TimeZone[n]].each do |z|
    k = z.class.name.split("::").last
    case n
    when "Australia/Lord_Howe"
      # DST ends 2026-04-05 02:00 +11 -> 01:30 +10:30
      a = Time.utc(2026, 4, 4, 14, 45).getlocal(z); b = Time.utc(2026, 4, 4, 15, 15).getlocal(z)
      show("#{n} #{k} a=#{a}") { a.change(min: 50) }
      show("#{n} #{k} b=#{b}") { b.change(min: 50) }
      show("#{n} #{k} b hour:1") { b.change(hour: 1, min: 40) }
    when "Pacific/Apia"
      a = Time.utc(2011, 12, 30, 9, 30).getlocal(z)
      show("#{n} #{k} a=#{a}") { a }
      show("#{n} #{k} day:30") { a.change(day: 30) }
      show("#{n} #{k} day:29") { a.change(day: 29) }
      show("#{n} #{k} adv -1d") { a.advance(days: -1) }
      p0 = Time.utc(2011, 12, 29, 9, 30).getlocal(z)
      show("#{n} #{k} p0=#{p0} day:30") { p0.change(day: 30) }
      show("#{n} #{k} p0 adv +1d") { p0.advance(days: 1) }
    when "Pacific/Kiritimati"
      a = Time.utc(1994, 12, 31, 9, 30).getlocal(z)
      show("#{n} #{k} a=#{a} day:31") { a.change(day: 31) }
    end
  end
end
