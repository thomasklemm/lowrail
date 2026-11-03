require "time"; require "pathname"; require "uri"
def count
  yield
  GC.disable
  b = GC.stat(:total_allocated_objects)
  1000.times { yield }
  (GC.stat(:total_allocated_objects) - b) / 1000.0
ensure
  GC.enable
end
t = Time.now; s = t.httpdate; p1 = Pathname.new("/a/b/c.txt"); m = Marshal.dump(t)
a = (1..20).to_a
rows = {
  "Time.httpdate(s)" => -> { Time.httpdate(s) },
  "Time.iso8601" => -> { Time.iso8601("2026-11-03T10:00:00Z") },
  "Pathname#join" => -> { p1.join("d") },
  "Pathname#basename" => -> { p1.basename },
  "Marshal.load(Time)" => -> { Marshal.load(m) },
  "URI.parse" => -> { URI.parse("https://localhost/a/b?c=1") },
  "a.map" => -> { a.map { _1 } },
  "a.select" => -> { a.select { _1.odd? } },
  "a.each_with_index" => -> { a.each_with_index { } },
  "{a: 1}.merge(b: 2)" => -> { {a: 1}.merge(b: 2) },
  "h.transform_values" => -> { {a: 1, b: 2}.transform_values { _1 } },
}
rows.each { |n, f| 2000.times { f.call }; printf("%-22s %6.2f\n", n, count(&f)) }
