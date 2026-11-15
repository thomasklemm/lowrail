# IMP336 integrity and nonce probe: preload tags of a custom map with integrity, across nil, string, false
# and empty nonces; diff the output of importmap-rails main and the branch. Run in the app:
#   BUNDLE_GEMFILE=Gemfile.main bundle exec ruby imp336_probe.rb > main.txt
ENV["RAILS_ENV"] = "production"
out = $stdout.dup; $stdout.reopen(File::NULL)
require "./config/environment"
def view(nonce)
  env = Rack::MockRequest.env_for("https://localhost/")
  unless nonce.nil?
    env["action_dispatch.content_security_policy"] = ActionDispatch::ContentSecurityPolicy.new { _1.script_src :self }
    env["action_dispatch.content_security_policy_nonce_generator"] = ->(_) { nonce }
    env["action_dispatch.content_security_policy_nonce_directives"] = %w[script-src]
  end
  c = PagesController.new; c.request = ActionDispatch::Request.new(env); c.view_context
end
m = Importmap::Map.new
m.enable_integrity!
m.pin "foo", to: "stimulus.min.js", preload: true, integrity: "sha384-abc"
m.pin "bar", to: "turbo.min.js", preload: true
m.pin "baz", to: "https://cdn.example/baz.js", preload: true, integrity: "sha384-\"q<>"
[nil, "n0", false, "", nil, "n1"].each do |n|
  out.puts n.inspect, view(n).javascript_importmap_module_preload_tags(m), view(n).javascript_importmap_tags("application", importmap: m)
  out.puts view(n).javascript_module_preload_tag("a.js", "b.js?x=<1>"), view(n).javascript_module_preload_tag
end
