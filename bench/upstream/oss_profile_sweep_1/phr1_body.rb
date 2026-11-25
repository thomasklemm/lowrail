# PHR1: PostHog::Rails::RequestContext on a browser page request without PostHog tracing headers, the common case
# for server-rendered pages. The env is captured where the railtie puts the middleware (before ShowExceptions) in
# a minimal Rails app, after a request with a browser's headers behind a proxy, as Puma passes them.
require "rails"
require "action_controller/railtie"
require "rack/mock"
require "posthog/rails"

captured = nil
capture = Class.new do
  define_method(:initialize) { |app| @app = app }
  define_method(:call) { |env| captured = env.dup; @app.call(env) }
end

app = Class.new(Rails::Application) do
  config.root = __dir__
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.hosts.clear
  routes.append { root to: ->(_env) { [200, {}, ["ok"]] } }
  initializer("capture_env", after: "posthog.insert_middlewares") do |a|
    a.middleware.insert_before PostHog::Rails::RequestContext, capture
  end
end
app.initialize!

headers = {
  "HTTP_HOST" => "dawarich.example.com",
  "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
  "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9",
  "HTTP_ACCEPT_ENCODING" => "gzip, deflate, br, zstd",
  "HTTP_COOKIE" => "_dawarich_session=#{'a' * 200}",
  "HTTP_REFERER" => "https://dawarich.example.com/map",
  "HTTP_CONNECTION" => "keep-alive",
  "HTTP_UPGRADE_INSECURE_REQUESTS" => "1",
  "HTTP_SEC_FETCH_DEST" => "document",
  "HTTP_SEC_FETCH_MODE" => "navigate",
  "HTTP_SEC_FETCH_SITE" => "same-origin",
  "HTTP_SEC_FETCH_USER" => "?1",
  "HTTP_SEC_CH_UA" => '"Chromium";v="131", "Not_A Brand";v="24"',
  "HTTP_SEC_CH_UA_MOBILE" => "?0",
  "HTTP_SEC_CH_UA_PLATFORM" => '"macOS"',
  "HTTP_PRIORITY" => "u=0, i",
  "HTTP_X_FORWARDED_FOR" => "203.0.113.10",
  "HTTP_X_FORWARDED_PROTO" => "https",
  "HTTP_X_REAL_IP" => "203.0.113.10",
  "HTTP_VERSION" => "HTTP/1.1",
  "SERVER_SOFTWARE" => "puma 7.1.0",
  "GATEWAY_INTERFACE" => "CGI/1.2",
  "REQUEST_URI" => "/stats?year=2026",
  "SERVER_PROTOCOL" => "HTTP/1.1",
  "REMOTE_ADDR" => "10.0.0.2",
  "puma.socket" => nil,
  "puma.config" => nil,
  "puma.request_body_wait" => 0.0
}
app.call(Rack::MockRequest.env_for("/stats?year=2026", headers))
raise "no env captured" unless captured

ok = [200, {}, ["ok"]].freeze
context = PostHog::Rails::RequestContext.new(->(_env) { ok })
context.call(captured)
headers_absent = ActionDispatch::Request.new(captured)

UpstreamBench.report("RequestContext#call (#{captured.size} env keys)") { context.call(captured) }
UpstreamBench.report("extract_header, header absent") do
  PostHog::Rails.const_get(:TracingHeaders).extract_header(headers_absent, "X-POSTHOG-SESSION-ID")
end
