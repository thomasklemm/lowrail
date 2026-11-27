# Cost of one rescuable-exception response in the test environment (debug page), and the upper bound on what source
# extracts cost: the same request with ExceptionWrapper#source_extracts returning [] (STUB=1).
#   ruby -I RAILS/<each framework>/lib debug_page_probe.rb   (Ruby 4.0.9; add --yjit for YJIT)
ENV["RAILS_ENV"] = "test"
require "rails"
require "action_controller/railtie"
require "benchmark"

class ProbeApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.enable_reloading = false # as the generated config/environments/test.rb
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :rescuable
  config.hosts.clear
  routes.append { get "/missing" => "probe#missing" }
end

class ProbeController < ActionController::Base
  def missing = params.require(:nothing)
end

ProbeApp.initialize!
ActionDispatch::ExceptionWrapper.prepend(Module.new { def source_extracts = [] }) if ENV["STUB"] == "1"
app = Rails.application
env = -> { Rack::MockRequest.env_for("/missing", "HTTP_ACCEPT" => "text/html") }
status = app.call(env.()).first
20.times { app.call(env.()) }
n = 200
before = GC.stat(:total_allocated_objects)
t = Benchmark.realtime { n.times { app.call(env.()) } }
objs = (GC.stat(:total_allocated_objects) - before) / n
frames = ActionDispatch::ExceptionWrapper.new(nil, (begin; ProbeController.new.missing; rescue => e; e; end)).backtrace.size rescue "?"
puts format("rails %s yjit=%s stub=%s status=%d: %.3f ms/request, %d objects/request", Rails::VERSION::STRING,
  defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?, ENV["STUB"] == "1", status, t * 1000 / n, objs)
