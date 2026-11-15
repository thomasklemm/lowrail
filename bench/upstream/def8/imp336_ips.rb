# IMP336 body benchmark (NONCE=1 adds a CSP nonce generator); imp336_run_ips.sh runs it interleaved.
require "benchmark/ips"

env = Rack::MockRequest.env_for("https://localhost/")
if ENV["NONCE"]
  env["action_dispatch.content_security_policy"] = ActionDispatch::ContentSecurityPolicy.new { |policy| policy.script_src :self }
  env["action_dispatch.content_security_policy_nonce_generator"] = ->(request) { SecureRandom.base64(16) }
  env["action_dispatch.content_security_policy_nonce_directives"] = %w[script-src]
end

controller = ApplicationController.new
controller.request = ActionDispatch::Request.new(env)
view = controller.view_context

Benchmark.ips do |x|
  x.report("javascript_importmap_tags") { view.javascript_importmap_tags }
end
