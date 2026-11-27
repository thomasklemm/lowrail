require "time"
%w[2026-02-30T00:00:00Z 2026-04-31T12:00:00Z 2026-02-30T00:00:00+09:00 2026-02-30T23:00:00-05:00 2026-04-31].each do |s|
  t = (s.size > 10 ? Time.iso8601(s) : Time.xmlschema(s + "T00:00:00Z")) rescue (puts "#{s} #{$!.class}"; next)
  puts "#{s.ljust(28)} -> #{t.iso8601} to_i=#{t.to_i} utc=#{t.utc.iso8601}"
end
