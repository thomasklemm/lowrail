# Allocation sites (file:line, top 25) of one debug-page response with source extracts stubbed, after warm-up.
ENV["STUB"] = "1"
require "objspace"
load File.expand_path("debug_page_probe.rb", __dir__)
app = Rails.application
5.times { app.call(Rack::MockRequest.env_for("/missing", "HTTP_ACCEPT" => "text/html")) }
counts = Hash.new(0)
GC.disable
ObjectSpace.trace_object_allocations do
  app.call(Rack::MockRequest.env_for("/missing", "HTTP_ACCEPT" => "text/html"))
  ObjectSpace.each_object do |o|
    f = ObjectSpace.allocation_sourcefile(o) or next
    next if ObjectSpace.allocation_generation(o) != GC.count
    counts["#{f.sub(%r{.*/(gems/|probe-\w+/)}, '')}:#{ObjectSpace.allocation_sourceline(o)}"] += 1
  end
end
counts.sort_by { -_2 }.first(25).each { |k, v| puts format("%6d %s", v, k) }
