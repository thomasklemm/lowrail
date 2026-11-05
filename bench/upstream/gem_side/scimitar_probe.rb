# frozen_string_literal: true

require "action_controller/railtie"
require "json"
require "stringio"

Mime::Type.register "application/gem-side+json", :gem_side
custom = ->(body) { {"custom" => body} }
ActionDispatch::Request.parameter_parsers = ActionDispatch::Request.parameter_parsers.merge(gem_side: custom)
before = ActionDispatch::Request.parameter_parsers
before.freeze

require "scimitar"

raise "Lost a parser" unless before.all? { |key, parser| ActionDispatch::Request.parameter_parsers[key].equal?(parser) }
raise "Mutated original registry" if before.key?(:scim)

results = []
[
  ["application/scim+json", '{"userName":"alpha","active":false,"name":{"givenName":"Beta"},"emails":[{"value":"x"}],"n":0}',
    {"userName" => "alpha", "active" => false, "name" => {"givenName" => "Beta"}, "emails" => [{"value" => "x"}], "n" => 0}],
  ["application/json", '{"ordinary":17}', {"ordinary" => 17}],
  ["application/gem-side+json", "raw", {"custom" => "raw"}]
].each do |type, body, expected|
  request = ActionDispatch::Request.new(
    "REQUEST_METHOD" => "POST", "CONTENT_TYPE" => type,
    "CONTENT_LENGTH" => body.bytesize.to_s, "rack.input" => StringIO.new(body)
  )
  actual = request.request_parameters.to_h
  raise "Wrong parameters: #{actual.inspect}" unless actual == expected
  results << actual
end

begin
  body = '{"userName":'
  request = ActionDispatch::Request.new(
    "REQUEST_METHOD" => "POST", "CONTENT_TYPE" => "application/scim+json",
    "CONTENT_LENGTH" => body.bytesize.to_s, "rack.input" => StringIO.new(body)
  )
  request.request_parameters
  raise "Invalid JSON accepted"
rescue ActionDispatch::Http::Parameters::ParseError => error
  raise "Wrong parse-error cause: #{error.cause.inspect}" unless error.cause.is_a?(JSON::ParserError)
  results << {error: error.class.name, cause: error.cause.class.name}
end

puts JSON.generate(results)
