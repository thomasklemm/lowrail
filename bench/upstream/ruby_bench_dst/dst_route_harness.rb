# Like dst_harness.rb, but the measured passes replay only the requests whose path is ROUTE, REPS times each.
require File.join(ENV.fetch("RUBY_BENCH_DIR", File.expand_path("~/src/ruby-bench")), "lib/harness")
def run_benchmark(_n, **)
  require ENV["FIX"] if ENV["FIX"]
  gen = ObjectSpace.each_object(RouteGenerator).first
  paths = gen.routes.map { _1["PATH_INFO"].dup }
  Integer(ENV.fetch("WARM", 3)).times { yield }
  picked = gen.routes.each_index.select { paths[_1] == ENV.fetch("ROUTE") }.map { gen.routes[_1] }
  gen.instance_variable_set(:@routes, picked * Integer(ENV.fetch("REPS", 5)))
  GC.start
  b = GC.stat(:total_allocated_objects)
  [0].cycle(1) { yield }
  n = gen.routes.size
  puts "DST route=#{ENV["ROUTE"]} requests=#{n} allocs/request=#{(GC.stat(:total_allocated_objects) - b).fdiv(n).round(1)} gc=#{GC.count} now=#{Time.now.utc}"
end
