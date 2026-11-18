require "json"
require "action_dispatch"
require "rack/mock"

def result
  value = yield
  { value: value }
rescue StandardError => error
  { error: error.class.name, message: error.message }
end

puts JSON.generate(ruby: RUBY_DESCRIPTION, rails: Gem.loaded_specs.fetch("actionpack").version.to_s,
  rack_utils: Rack::Utils.method(:unescape).source_location)
counts = Hash.new(0)
trace = TracePoint.new(:call) do |event|
  if event.method_id == :unescape && [Rack::Utils, Rack::Utils.singleton_class, Rack::QueryParser].include?(event.defined_class)
    counts[event.defined_class == Rack::QueryParser ? "Rack::QueryParser" : "Rack::Utils"] += 1
  end
end
trace.enable
["name=a+%2B&x=%E3%81%82", "x=%FF", "x=%", "x=%%", "x=%2a%7e%2B"].each do |query|
  counts.clear
  get = result { ActionDispatch::Request.new(Rack::MockRequest.env_for("/?#{query}")).GET }
  get_counts = counts.dup
  counts.clear
  post = result do
    env = Rack::MockRequest.env_for("/", method: "POST", input: query, "CONTENT_TYPE" => "application/x-www-form-urlencoded")
    ActionDispatch::Request.new(env).POST
  end
  puts JSON.generate(query: query, get: get, post: post, get_decode_calls: get_counts, post_decode_calls: counts)
end
counts.clear
cookie_env = Rack::MockRequest.env_for("/", "HTTP_COOKIE" => "name=a+%2B; invalid=%; mixed=%2a%7e%2B")
puts JSON.generate(cookies: result { ActionDispatch::Request.new(cookie_env).cookies }, decode_calls: counts)
response = ActionDispatch::Response.new
response.set_cookie("name", value: "a +*~", httponly: true, same_site: :lax)
puts JSON.generate(set_cookie: response.headers["set-cookie"])
trace.disable
