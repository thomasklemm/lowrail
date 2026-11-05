# RAILS=path ruby debug_exceptions_arity.rb -> prepends a two-argument render_for_browser_request, the shape of
# inertia_rails <= 3.15.0's lib/patches/debug_exceptions.rb, and renders an error page through DebugExceptions.
# 8-1: 500 with the HTML error page; main: ArgumentError (main passes a third content_type argument).
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[actionpack actionview activesupport].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
end
require "action_dispatch"
require "action_view"
module TwoArgumentPatch
  def render_for_browser_request(request, wrapper)
    super
  end
end
ActionDispatch::DebugExceptions.prepend(TwoArgumentPatch)
app = ->(_env) { raise "boom" }
stack = ActionDispatch::DebugExceptions.new(app)
env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "text/html", "action_dispatch.show_detailed_exceptions" => true,
                                "action_dispatch.show_exceptions" => :all)
begin
  status, headers, = stack.call(env)
  puts "#{ActionPack.version}: #{status} #{headers["content-type"]}"
  exit 0
rescue ArgumentError => error
  puts "#{ActionPack.version}: #{error.class}: #{error.message}"
  exit 1
end
