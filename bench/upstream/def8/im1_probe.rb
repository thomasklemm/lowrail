# frozen_string_literal: true

# IM1 differential probe: prints what the importmap tag helpers return across
# request shapes, so base and branch outputs can be diffed. Run in a generated
# app with a Gemfile that points importmap-rails at the tree under test:
#   BUNDLE_GEMFILE=Gemfile.imb bundle exec ruby im1_probe.rb > base.txt
ENV["RAILS_ENV"] = "production"
$stdout.sync = true
out = $stdout.dup
$stdout.reopen(File::NULL)
require "./config/environment"

def view(nonce: nil, request: true)
  c = PagesController.new
  env = Rack::MockRequest.env_for("https://localhost/home", "REMOTE_ADDR" => "127.0.0.1")
  env["action_dispatch.content_security_policy_nonce"] = nonce if nonce
  if nonce
    env["action_dispatch.content_security_policy"] = ActionDispatch::ContentSecurityPolicy.new { _1.script_src :self }
    env["action_dispatch.content_security_policy_nonce_generator"] = ->(_) { nonce }
    env["action_dispatch.content_security_policy_nonce_directives"] = %w[script-src]
  end
  c.request = ActionDispatch::Request.new(env) if request
  c.response = ActionDispatch::Response.new
  c.view_context
end

def show(out, label, value)
  out.puts "#{label}: #{value.class} html_safe=#{value.html_safe?} frozen=#{value.frozen?}"
  out.puts value
end

custom = Importmap::Map.new
custom.pin "foo", preload: true
custom.pin "bar", preload: false
custom.pin "baz", preload: "admin"

steps = [
  ["plain", -> { view.javascript_importmap_module_preload_tags }],
  ["plain again", -> { view.javascript_importmap_module_preload_tags }],
  ["nonce", -> { view(nonce: "n0nce").javascript_importmap_module_preload_tags }],
  ["plain after nonce", -> { view.javascript_importmap_module_preload_tags }],
  ["other nonce", -> { view(nonce: "other").javascript_importmap_module_preload_tags }],
  ["no request", -> { view(request: false).javascript_importmap_module_preload_tags }],
  ["full tags", -> { view.javascript_importmap_tags }],
  ["full tags nonce", -> { view(nonce: "n0nce").javascript_importmap_tags }],
  ["custom map", -> { view.javascript_importmap_module_preload_tags(custom) }],
  ["custom map admin", -> { view.javascript_importmap_module_preload_tags(custom, entry_point: "admin") }],
  ["custom map array", -> { view.javascript_importmap_module_preload_tags(custom, entry_point: %w[application admin]) }],
  ["custom full admin", -> { view.javascript_importmap_tags("admin", importmap: custom) }],
  ["mutated result", -> { view.javascript_importmap_module_preload_tags.tap { _1 << "<!-- appended -->".html_safe } }],
  ["after mutation", -> { view.javascript_importmap_module_preload_tags }],
  ["pin added", -> { custom.pin "qux", preload: true; view.javascript_importmap_module_preload_tags(custom) }],
  ["module preload tag", -> { view.javascript_module_preload_tag("a.js", "b.js") }],
  ["identity differs", -> { a = view.javascript_importmap_module_preload_tags; b = view.javascript_importmap_module_preload_tags; (!a.equal?(b)).to_s }]
]
steps.each do |label, step|
  show(out, label, step.call)
rescue => e
  out.puts "#{label}: #{e.class}: #{e.message}"
end
