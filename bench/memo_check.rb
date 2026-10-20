# frozen_string_literal: true

# Untimed production probe; compare the resulting JSON off/on in each cache
# mode. Only CSP bytes are exported, never authentication/session headers.
require File.expand_path("config/environment", Dir.pwd)
require "json"
require "rack/mock"
Rails.application.eager_load!
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil
paths = JSON.parse(File.read("tmp/m0/paths.json"))
headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(File.read("tmp/m0/headers.json")))
client = Rack::MockRequest.new(Rails.application)
results = %w[room messages sidebar search].to_h do |name|
  response = nil
  3.times { response = client.get(paths.fetch(name), headers) }
  raise "#{name}: #{response.status}" unless response.status == 200
  expected = { "room" => "Champagne", "messages" => "Champagne", "sidebar" => "All Talk", "search" => "Pain is easy to write" }.fetch(name)
  raise "#{name}: missing expected fixture" unless response.body.include?(expected)
  policy = response["content-security-policy"]
  raise "#{name}: missing CSP" unless policy && policy.include?("script-src") && policy.include?("sha256-")
  [name, { status: response.status, csp: policy, report_only: response["content-security-policy-report-only"] }]
end
Lowrail.write_json(ENV.fetch("MEMO_CHECK_JSON"), results)
puts JSON.generate({ routes: results.size, hits: defined?(Lowrail::Stats) ? Lowrail::Stats.unit_hits : {} })
