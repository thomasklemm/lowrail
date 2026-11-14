# frozen_string_literal: true

# AB1 (allow_browser verdict cache): one controller request through allow_browser :modern.
# Run inside a census copy so its bundle supplies Rails and useragent:
#   bench/upstream/p_map/hx censuspmap blog bundle exec ruby -I BENCHMARK_IPS_LIB THIS
require "action_controller"
require "benchmark/ips"

class PagesController < ActionController::Base
  allow_browser versions: :modern

  def show = head(:ok)
end

app = PagesController.action(:show)
user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
raise "blocked" unless app.call(Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => user_agent)).first == 200

Benchmark.ips do |x|
  x.report("request with allow_browser") { app.call(Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => user_agent)) }
end
