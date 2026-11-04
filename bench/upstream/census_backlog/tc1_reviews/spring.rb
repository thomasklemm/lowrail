require "active_support/all"
[TZInfo::Timezone.get("Europe/Berlin"), ActiveSupport::TimeZone["Europe/Berlin"]].each do |z|
  r = ->(&b) { begin; v = b.call; "#{v.inspect} utc=#{v.utc_offset} zone_same=#{v.zone.equal?(z)}"; rescue => e; "#{e.class}: #{e.message}"; end }
  before = Time.utc(2026,3,29,0,30).getlocal(z)
  after  = Time.utc(2026,3,29,1,30).getlocal(z)
  jul = Time.utc(2026,7,1,12).getlocal(z); jan = Time.utc(2026,1,15,12).getlocal(z)
  puts z.class
  puts " before #{before.inspect} after #{after.inspect}"
  puts " gap from before: " + r.() { before.change(hour: 2, min: 30) }
  puts " gap from after:  " + r.() { after.change(hour: 2, min: 30) }
  puts " before min0: " + r.() { before.change(min: 0) }
  puts " after  min0: " + r.() { after.change(min: 0) }
  puts " jul->jan: " + r.() { jul.change(month: 1) }
  puts " jan->jul: " + r.() { jan.change(month: 7) }
end
