# frozen_string_literal: true

# Boot APP as the census does and record each RoutesReloader#load_paths call
# (one per routes draw) with its CPU time and objects. ruby inapp.rb APP boot_route_draws.rb
require_relative "../census/harness"
$draws = []
mod = Module.new do
  def load_paths
    t = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID); o = GC.stat(:total_allocated_objects)
    super
  ensure
    from = caller_locations.find { _1.path.include?("devise") } ? "devise" : "rails"
    $draws << [from, ((Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t) * 1000).round(1), GC.stat(:total_allocated_objects) - o]
  end
end
require "bundler/setup"; require "rails"; require "rails/application/routes_reloader"
Rails::Application::RoutesReloader.prepend(mod)
t0 = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
RailsCensus.boot(ARGV[0])
boot = ((Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t0) * 1000).round
warn "DRAWS #{ARGV[0]} boot #{boot} ms, routes #{Rails.application.routes.routes.size}, draws #{$draws.inspect}"
