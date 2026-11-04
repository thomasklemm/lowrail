require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activesupport", "lib")
require "active_support"; require "active_support/core_ext/time"; require "bigdecimal"
I = Struct.new(:v) { def to_int = v; def to_i = v }
f = ->(v) { v.is_a?(Time) ? "#{v.strftime('%F %T.%N %z')} #{v.subsec.inspect}" : v.inspect }
zs = [ActiveSupport::TimeZone["Europe/Berlin"], TZInfo::Timezone.get("America/New_York"), ActiveSupport::TimeZone["Asia/Kolkata"]]
vals = [2026.9, Rational(4053, 2), BigDecimal("3.5"), I.new(5), -1, -61, 61, 1e20, "07", " 7", "0x10", :jan, "Jan", 2**64, -2**64, Float::NAN, Float::INFINITY, Object.new, true]
zs.each do |z|
  t = Time.utc(2026, 7, 15, 10, 20, 30, 123456).getlocal(z)
  %i[year month day hour min sec usec nsec].each do |k|
    vals.each do |v|
      r = begin; f.(t.change(k => v)); rescue Exception => e; "#{e.class}: #{e.message[0, 50]}"; end
      puts "#{z.name rescue z.identifier} #{k}=#{v.inspect[0, 20]} => #{r}"
    end
  end
end
