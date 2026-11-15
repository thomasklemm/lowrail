# IMP336: allocations per javascript_importmap_tags call (NONCE=1 adds a CSP nonce generator):
#   BUNDLE_GEMFILE=Gemfile.main RAILS_ENV=production bin/rails runner imp336_allocs.rb
env = Rack::MockRequest.env_for("https://localhost/")
if ENV["NONCE"]
  env["action_dispatch.content_security_policy"] = ActionDispatch::ContentSecurityPolicy.new { |policy| policy.script_src :self }
  env["action_dispatch.content_security_policy_nonce_generator"] = ->(request) { SecureRandom.base64(16) }
  env["action_dispatch.content_security_policy_nonce_directives"] = %w[script-src]
end
controller = ApplicationController.new
controller.request = ActionDispatch::Request.new(env)
view = controller.view_context
5.times { view.javascript_importmap_tags }
counts = 3.times.map do
  before = GC.stat(:total_allocated_objects)
  view.javascript_importmap_tags
  GC.stat(:total_allocated_objects) - before
end
puts counts.inspect
