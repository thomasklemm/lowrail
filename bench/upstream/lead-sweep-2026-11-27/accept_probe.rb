# frozen_string_literal: true
# Mime::Type.parse on real browser Accept headers: objects and time per parse (Rails tree as ARGV[0]).
rails = ARGV.fetch(0)
%w[activesupport actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "action_dispatch"
require "action_dispatch/http/mime_type"
require "benchmark/ips"
HEADERS = {
  "firefox" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "chrome" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
  "safari" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "turbo" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
}
Mime::Type.register "text/vnd.turbo-stream.html", :turbo_stream
HEADERS.each do |n, h|
  r = Mime::Type.parse(h)
  1000.times { Mime::Type.parse(h) }
  b = GC.stat(:total_allocated_objects); 1000.times { Mime::Type.parse(h) }
  puts format("%-8s objects %.1f  -> %s", n, (GC.stat(:total_allocated_objects) - b) / 1000.0, r.map(&:to_s).join(" "))
end
exit if ENV["NOIPS"]
Benchmark.ips(quiet: true) do |x|
  x.config(time: 2, warmup: 1)
  HEADERS.each { |n, h| x.report(n) { Mime::Type.parse(h) } }
end.entries.each { |e| puts format("%-8s %8.0f ns", e.label, 1e9 / e.ips) }
