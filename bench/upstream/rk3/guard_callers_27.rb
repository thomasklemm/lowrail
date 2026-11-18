# Ruby 2.7: String#split keeps String subclasses, so Rack's own parsers pass subclass pieces to unescape.
require "rack"; require "rack/request"; require "rack/mock_request"
Sub = Class.new(String)
puts "#{RUBY_VERSION} split: #{Sub.new("a=b").split("=").map(&:class).inspect}"
puts "parse_query(Sub 'a=b&c=%41'): #{Rack::Utils.parse_query(Sub.new("a=b&c=%41")).values.map(&:class).inspect}"
puts "parse_nested_query(Sub 'a=b'): #{Rack::Utils.parse_nested_query(Sub.new("a=b")).values.map(&:class).inspect}"
puts "Request#GET with Sub QUERY_STRING: #{Rack::Request.new(Rack::MockRequest.env_for("/").merge("QUERY_STRING" => Sub.new("a=b"))).GET.values.map(&:class).inspect}"
puts "Request#cookies with Sub HTTP_COOKIE: #{Rack::Request.new(Rack::MockRequest.env_for("/").merge("HTTP_COOKIE" => Sub.new("a=b"))).cookies.values.map(&:class).inspect}"
