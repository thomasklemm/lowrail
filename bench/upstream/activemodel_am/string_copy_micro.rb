require "objspace"
def cnt; a = GC.stat(:total_allocated_objects); r = yield; [GC.stat(:total_allocated_objects) - a - 0, r]; end
def best(n=1_000_000); b=1e9; 5.times { t=Process.clock_gettime(Process::CLOCK_MONOTONIC); i=0; while i<n; yield; i+=1; end; b=[b,Process.clock_gettime(Process::CLOCK_MONOTONIC)-t].min }; (b*1e9/n).round(1); end
[19, 60, 300].each do |n|
  [false, true].each do |fz|
    src = ->{ s = ("a" * n); fz ? s.freeze : s }
    o1, r1 = cnt { String.new(src0 = src.()) } rescue nil
    s1 = src.(); s2 = src.()
    on, rn = cnt { String.new(s1) }; od, rd = cnt { s2.dup }
    # fresh source each call, like loading rows
    pool1 = Array.new(1_000_000) { src.() }; i = -1
    tn = best(1_000_000) { String.new(pool1[i += 1] || pool1[0]) }
    pool2 = Array.new(1_000_000) { src.() }; j = -1
    td = best(1_000_000) { (pool2[j += 1] || pool2[0]).dup }
    puts "len=#{n} frozen=#{fz}: String.new #{on} obj #{ObjectSpace.memsize_of(rn)}B #{tn}ns | dup #{od} obj #{ObjectSpace.memsize_of(rd)}B #{td}ns"
  end
end
