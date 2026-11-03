# Shape of URI::RFC3986_Parser#parse: URI.for(*self.split(uri), self)
module U; def self.for(scheme, *arguments, default: nil) = scheme; end
class S
  def split(s) = [s, 1, 2]
  def parse(s) = U.for(*split(s), self)
  def parse2(s) = U.for(*split(s))
end
def count
  yield
  GC.disable
  b = GC.stat(:total_allocated_objects)
  1000.times { yield }
  (GC.stat(:total_allocated_objects) - b) / 1000.0
ensure
  GC.enable
end
s = S.new
20_000.times { s.parse("x"); s.parse2("x") } # let the JITs compile
puts format("U.for(*split(s), self) %.2f   U.for(*split(s)) %.2f", count { s.parse("x") }, count { s.parse2("x") })
