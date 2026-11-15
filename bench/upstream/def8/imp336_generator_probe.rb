# IMP336: how often a page calls the CSP nonce generator, and what a later plain page gets after a generator
# that returns nil first and a string next. Diff main and the branch:
#   BUNDLE_GEMFILE=Gemfile.main bundle exec ruby imp336_generator_probe.rb
ENV["RAILS_ENV"] = "production"
out = $stdout.dup; $stdout.reopen(File::NULL)
require "./config/environment"
def view(generator)
  env = Rack::MockRequest.env_for("https://localhost/")
  if generator
    env["action_dispatch.content_security_policy"] = ActionDispatch::ContentSecurityPolicy.new { _1.script_src :self }
    env["action_dispatch.content_security_policy_nonce_generator"] = generator
    env["action_dispatch.content_security_policy_nonce_directives"] = %w[script-src]
  end
  c = PagesController.new; c.request = ActionDispatch::Request.new(env); c.view_context
end
[nil, false, "s"].each do |value|
  calls = 0
  view(->(_) { calls += 1; value }).javascript_importmap_tags
  out.puts "generator returning #{value.inspect}: #{calls} calls per page"
end
map = Importmap::Map.new
map.pin "stimulus", to: "stimulus.min.js", preload: true
values = [nil, "late"]
out.puts "generator returning nil, then \"late\":", view(->(_) { values.shift }).javascript_importmap_module_preload_tags(map)
out.puts "next plain page:", view(nil).javascript_importmap_module_preload_tags(map)
