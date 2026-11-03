# ruby -I RAILS/actionpack/lib ... route_source.rb : time RouteSet#draw of N resources with route_source_locations.
require "bundler/setup"
require "action_controller"
require "action_dispatch"
ActionDispatch::Routing::Mapper.route_source_locations = true
N = Integer(ENV.fetch("N", "100"))
clock = -> { Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) }
draw = -> { rs = ActionDispatch::Routing::RouteSet.new; rs.draw { N.times { |i| resources :"r#{i}" } }; rs }
3.times { draw.() }
routes = draw.().routes.size
best = 7.times.map { t = clock.(); 5.times { draw.() }; (clock.() - t) / 5 }.min
calls = 0
srcloc = ActionDispatch::Routing::Mapper::Mapping.instance_method(:route_source_location)
m = ActionDispatch::Routing::Mapper::Mapping.allocate
t = clock.(); 20_000.times { srcloc.bind_call(m) }; per = (clock.() - t) / 20_000
puts "#{ENV.fetch("LABEL")} #{RUBY_VERSION}#{" yjit" if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}#{" zjit" if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?} #{$LOADED_FEATURES.grep(/routing\/mapper.rb/).first[/rails-wt\/[\w-]+/]}: draw #{routes} routes #{(best * 1000).round(2)} ms (#{(best * 1e6 / routes).round(2)} us/route); route_source_location #{(per * 1e9).round} ns/call"
