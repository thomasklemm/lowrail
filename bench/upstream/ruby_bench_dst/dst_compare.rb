# Differential check: prints every result of the TimeWithZone operations that
# reach wrap_with_time_zone or change, around every transition of each zone.
# Run once per Active Support checkout and diff the outputs.
require "bundler/setup"
require "active_support"
require "active_support/core_ext/time"
require "active_support/core_ext/date_time"
require "active_support/core_ext/numeric/time"
require "digest"

shard, shards = (ARGV[0] || "0/1").split("/").map(&:to_i)
EXTRA = %w[Europe/Dublin Africa/Casablanca Australia/Lord_Howe Europe/Moscow America/Sao_Paulo Pacific/Apia
  America/Caracas Antarctica/Troll Etc/GMT+5 Asia/Kolkata America/St_Johns Pacific/Kiritimati Asia/Gaza
  America/Godthab Europe/Lisbon Asia/Tehran Pacific/Chatham America/Havana]
zones = (ActiveSupport::TimeZone.all.map(&:name) + EXTRA).uniq.each_with_index.select { |_, i| i % shards == shard }.map(&:first)
OTHER = %w[UTC Europe/Berlin America/New_York Australia/Lord_Howe Europe/Dublin].map { ActiveSupport::TimeZone[_1] }
FROM, TO = Time.utc(1900), Time.utc(2045)
OFFSETS = [-26, -25, -24, -23, -3, -2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2, 3, 23, 24, 25, 26].flat_map { [_1 * 3600, _1 * 3600 - 1, _1 * 3600 + 1] }.uniq
OPS = {
  "ago1" => -> t { 1.day.ago(t) }, "since1" => -> t { t + 1.day }, "minus7" => -> t { t - 7.days },
  "ago70" => -> t { 70.days.ago(t) }, "mon+1" => -> t { t + 1.month }, "mon-1" => -> t { t.advance(months: -1) },
  "yr-1" => -> t { t - 1.year }, "wk+1" => -> t { t.advance(weeks: 1) }, "days+0" => -> t { t.advance(days: 0) },
  "hours1" => -> t { t.advance(hours: 1) }, "bod" => -> t { t.beginning_of_day }, "eod" => -> t { t.end_of_day },
  "boh" => -> t { t.beginning_of_hour }, "mid" => -> t { t.middle_of_day }, "bom" => -> t { t.beginning_of_month },
  "h0" => -> t { t.change(hour: 0) }, "h1" => -> t { t.change(hour: 1) }, "h2" => -> t { t.change(hour: 2) },
  "h3" => -> t { t.change(hour: 3) }, "m30" => -> t { t.change(min: 30) }, "s0" => -> t { t.change(sec: 0) },
  "usec" => -> t { t.change(usec: 5) }, "dst_chain" => -> t { (t + 1.day).change(min: 15) - 1.day },
  "succ_meth" => -> t { t.tomorrow }, "yest" => -> t { t.yesterday }, "range" => -> t { t.all_day },
  **OTHER.to_h { |z| ["zone_#{z.name}", -> t { t.change(zone: z) }] },
  "offset" => -> t { t.change(offset: "+05:30") },
}

def show(r)
  return r.inspect unless r.is_a?(ActiveSupport::TimeWithZone)
  p = r.period
  [r.inspect, r.utc.to_r, r.time.to_a, r.utc_offset, r.dst?, r.zone, r.time_zone.name,
   p.start_transition&.timestamp_value, p.end_transition&.timestamp_value, p.observed_utc_offset].join("|")
end

CASES = Hash.new(0)
ActiveSupport::TimeZone.prepend(Module.new {
  def periods_for_local(t) = super.tap { CASES["periods_#{_1.size}"] += 1 }
  def period_for_local(t, dst = true) = (CASES[:refetch] += 1; super)
})
digest = Digest::SHA256.new; count = 0
out = ENV["OUT"] && File.open(ENV["OUT"], "w")
zones.each do |name|
  zone = ActiveSupport::TimeZone[name]
  instants = zone.tzinfo.transitions_up_to(TO, FROM).map(&:at).map(&:to_time)
  instants = [Time.utc(1970), Time.utc(2026, 7, 1)] if instants.empty?
  bases = instants.flat_map { |at| OFFSETS.map { at + _1 + Rational(1, 3) } }
  bases.each do |u|
    [ActiveSupport::TimeWithZone.new(u, zone), ActiveSupport::TimeWithZone.new(u.to_datetime, zone)].each_with_index do |t, kind|
      OPS.each do |op, f|
        next if kind == 1 && !%w[ago1 bod h2 mon+1].include?(op)
        line = begin
          "#{name}|#{u.to_r}|#{kind}|#{op}|#{show(f.(t))}"
        rescue => e
          "#{name}|#{u.to_r}|#{kind}|#{op}|#{e.class}: #{e.message}"
        end
        digest << line << "\n"; count += 1
        out&.puts line
      end
    end
  end
end
puts "#{count} #{digest.hexdigest} #{CASES.inspect}"
