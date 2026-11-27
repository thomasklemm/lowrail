# DV1 body numbers (script/upstream-bench): one request whose action raises a rescuable exception, rendered as the
# debug page with the generated config/environments/test.rb settings (show_exceptions :rescuable, local requests,
# template caching on), and the page HostAuthorization renders for a blocked host.
ENV["RAILS_ENV"] = "test"
require "rails"
require "action_controller/railtie"

class BenchApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.enable_reloading = false
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :rescuable
  config.hosts << "www.example.com"
  routes.append { get "/missing" => "bench#missing" }
end

class BenchController < ActionController::Base
  def missing = params.require(:nothing)
end

BenchApp.initialize!
app = Rails.application
debug_page = -> { app.call(Rack::MockRequest.env_for("/missing", "HTTP_HOST" => "www.example.com", "HTTP_ACCEPT" => "text/html")) }
blocked_host = -> { app.call(Rack::MockRequest.env_for("/missing", "HTTP_HOST" => "blocked.example.org", "HTTP_ACCEPT" => "text/html")) }
raise "debug page: #{debug_page.().first}" unless debug_page.().first == 400
raise "blocked host: #{blocked_host.().first}" unless blocked_host.().first == 403

UpstreamBench.report("debug page (400)") { debug_page.() }
UpstreamBench.report("blocked host page (403)") { blocked_host.() }
