# Registering a parameter parser by mutating ActionDispatch::Request.parameter_parsers,
# as scimitar 2.15.0's engine does. RAILS=/path/to/rails ruby param_parsers.rb
rails = ENV.fetch("RAILS")
%w[activesupport actionpack actionview activemodel].each { |g| $LOAD_PATH.unshift File.join(rails, g, "lib") }
require "action_controller"
require "json"

Mime::Type.register "application/scim+json", :scim
begin
  ActionDispatch::Request.parameter_parsers[:scim] = ->(body) { JSON.parse(body) }
  env = Rack::MockRequest.env_for("/", method: "POST", input: '{"a":1}', "CONTENT_TYPE" => "application/scim+json")
  puts "registered; params: #{ActionDispatch::Request.new(env).request_parameters.inspect}"
rescue => e
  puts "#{e.class}: #{e.message}"
end
