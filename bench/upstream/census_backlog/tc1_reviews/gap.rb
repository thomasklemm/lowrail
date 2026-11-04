require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activesupport", "lib")
require "active_support"; require "active_support/core_ext/time"
TZInfo::Timezone.default_dst = {"nil"=>nil,"true"=>true,"false"=>false}[ENV.fetch("DDST","nil")]
ActiveSupport.utc_to_local_returns_utc_offset_times = ENV["UOT"] == "1"
f = ->(v) { v.is_a?(Time) ? "#{v.strftime('%F %T.%N %z')} #{v.zone.class}" : v.class.to_s }
TZInfo::Timezone.all_identifiers.each do |id|
  tz = TZInfo::Timezone.get(id)
  as = ActiveSupport::TimeZone.new(id)
  tz.transitions_up_to(Time.utc(2037)).each do |tr|
    d = tr.offset.observed_utc_offset - tr.previous_offset.observed_utc_offset
    next unless d > 0
    at = tr.at.to_time
    [at - 1, at - d / 2, at + 1, at + d / 2].each do |u|
      [["tz", tz], ["as", as]].each do |k, z|
        t = u.getlocal(z) rescue next
        [{min: (t + d/2).min, hour: (t + d/2).hour}, {min: (t - d/2).min, hour: (t - d/2).hour}, {nsec: 0}, {hour: (t + d).hour}].each do |o|
          r = begin; f.(t.change(o)); rescue => e; e.class.to_s; end
          puts "#{k}:#{id}|#{f.(t)}|#{o}|#{r}"
        end
      end
    end
  end
end
