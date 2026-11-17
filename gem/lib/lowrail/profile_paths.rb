# frozen_string_literal: true

# bin/rails runner workload for lowrail-profile --paths FILE: one request per
# line ("GET /articles", or just "/articles"), through the app's full
# middleware stack, 10 warmup passes and 20 counted ones (counts reset after
# warmup). Lines starting with # are skipped. A response that is not 2xx or
# 3xx aborts, so a broken path is not profiled as an error page.
require "rack/mock"

file = ARGV.fetch(0)
requests = File.readlines(file, chomp: true).map(&:strip).reject { _1.empty? || _1.start_with?("#") }.map do |line|
  verb, path = line.split(/\s+/, 2)
  path ? [verb.upcase, path] : ["GET", verb]
end
host = ENV.fetch("LOWRAIL_PROFILE_HOST", "localhost")
# A browser's headers, as the census sends: apps branch on them (allow_browser).
headers = { "HTTP_ACCEPT" => "text/html", "HTTP_SEC_FETCH_SITE" => "same-origin",
  "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0" }
# Cookies are kept from response to response, as a browser keeps the session.
cookies = {}
run = lambda do
  requests.each do |verb, path|
    cookie = cookies.map { "#{_1}=#{_2}" }.join("; ")
    env = Rack::MockRequest.env_for("https://#{host}#{path}", method: verb, **headers,
      **(cookie.empty? ? {} : { "HTTP_COOKIE" => cookie }))
    status, response_headers, body = Rails.application.call(env)
    body.close if body.respond_to?(:close)
    Array(response_headers["set-cookie"]).flat_map { _1.split("\n") }.each do |line|
      name, value = line.split(";", 2).first.split("=", 2)
      line.match?(/;\s*max-age=0|;\s*expires=Thu, 01 Jan 1970/i) ? cookies.delete(name) : cookies[name] = value
    end
    abort "lowrail-profile: #{verb} #{path} returned #{status}" unless (200..399).cover?(status)
  end
end
10.times { run.call }
Lowrail::Profile.reset if defined?(Lowrail::Profile)
20.times { run.call }
