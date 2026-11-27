# Allocations of WebMock's URI normalisation for a URL seen before vs a new one (the since= second changes).
require "webmock"
n = ->(u) { GC.disable; a = GC.stat(:total_allocated_objects); WebMock::Util::URI.normalize_uri(u); GC.stat(:total_allocated_objects) - a }
u = ->(t) { "https://api.github.com/repos/o/r/commits?author=x&per_page=100&since=#{t.utc.iso8601}" }
t = Time.now
n.(u.(t - 3600))
puts "new url: #{n.(u.(t))}, same url again: #{n.(u.(t))}, next second: #{n.(u.(t + 1))}"
