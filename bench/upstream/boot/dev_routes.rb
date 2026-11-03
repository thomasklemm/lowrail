# frozen_string_literal: true

# Development-mode route redraw: boot in development, then time
# Rails.application.reload_routes! (what a change to config/routes.rb or a
# reload costs in RoutesReloader) BOOT_REDRAWS times, best and median.
#   ruby dev_routes.rb APP    (census copy, census env, RAILS_ENV=development)
require "bundler/setup"
require "json"
ENV.update("RAILS_ENV" => "development", "RACK_ENV" => "development", "LOWRAIL" => "0")
require File.expand_path("config/application")
Rails.application.config.yjit = false
require File.expand_path("config/environment")
raise "route source locations are off" unless ActionDispatch::Routing::Mapper.route_source_locations
clock = -> { Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) }
2.times { Rails.application.reload_routes! }
times = Integer(ENV.fetch("BOOT_REDRAWS", "15")).times.map do
  GC.start
  t = clock.()
  Rails.application.reload_routes!
  (clock.() - t) * 1000
end.sort
puts JSON.generate(app: ARGV[0], rails: Gem.loaded_specs["actionpack"].full_gem_path[/rails-\h+/], routes: Rails.application.routes.routes.size,
  best_ms: times.first.round(2), median_ms: times[times.size / 2].round(2))
