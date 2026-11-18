# frozen_string_literal: true

# bin/rails runner workload for lowrail-profile --workloads FILE: the file's
# requests (lowrail/workloads.rb, gem/lib/lowrail/workloads.rb) through the
# app's full middleware stack, 10 warmup passes and 20 counted ones (counts
# reset after warmup), with a browser's headers and the cookies earlier
# responses set. A response outside the request's expect: aborts, so a broken
# path is not profiled as an error page. Mails, jobs and the jobs requests
# enqueue are not run here (the census runs them); the receipt says which.
require "rack/mock"
require "json"
require_relative "workloads"

file, receipt = ARGV.fetch(0), ARGV[1]
definition = Lowrail::Workloads.load(file)
host = ENV.fetch("LOWRAIL_PROFILE_HOST", "localhost")
# A browser's headers, as the census sends: apps branch on them (allow_browser).
BROWSER = { "HTTP_ACCEPT" => "text/html", "HTTP_SEC_FETCH_SITE" => "same-origin",
  "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0" }.freeze

# Cookies are kept from response to response, as a browser keeps the session.
client = Class.new do
  def initialize(host) = (@host, @cookies = host, {})

  def cookie(name, value) = @cookies[name] = value

  def request(verb, path, params: {}, body: nil, headers: {}, expect: [200], name: "#{verb.upcase} #{path}", read: false)
    cookie = @cookies.map { "#{_1}=#{_2}" }.join("; ")
    opts = { method: verb.to_s.upcase, **BROWSER, **headers, **(cookie.empty? ? {} : { "HTTP_COOKIE" => cookie }) }
    if body then opts[:input] = body
    elsif !params.empty? then opts[:params] = params
    end
    status, response_headers, response = Rails.application.call(Rack::MockRequest.env_for("https://#{@host}#{path}", opts))
    text = +""
    response.each { text << _1 } if read
    response.close if response.respond_to?(:close)
    Array(response_headers["set-cookie"]).flat_map { _1.split("\n") }.each do |line|
      key, value = line.split(";", 2).first.split("=", 2)
      line.match?(/;\s*max-age=0|;\s*expires=Thu, 01 Jan 1970/i) ? @cookies.delete(key) : @cookies[key] = value
    end
    abort "lowrail-profile: #{name}: #{verb.upcase} #{path} returned #{status} (expected #{expect.join(" or ")})" unless expect.include?(status)
    text
  end

  def token(path)
    body = request(:get, path, read: true, name: "the CSRF page")
    body[/<meta name="csrf-token" content="([^"]+)"/, 1] || body[/name="authenticity_token" value="([^"]+)"/, 1]
  end
end

signed_in, anonymous = client.new(host), client.new(host)
if (s = definition.sign_in_spec)
  if (cookie = s[:cookie])
    name, value = cookie.fetch(:name).to_s, cookie.fetch(:value).to_s
    if cookie[:signed]
      # Signed with the app's own key generator, as the census signs it.
      require "action_dispatch/testing/test_request"
      request = ActionDispatch::TestRequest.create
      request.env.merge!(Rails.application.env_config)
      request.cookie_jar.signed[name.to_sym] = value
      name, value = request.cookie_jar.to_header.split("=", 2)
    end
    signed_in.cookie(name, value)
  else
    token = signed_in.token(s[:form])
    signed_in.request(s[:method], s[:path], params: token ? s[:params].merge("authenticity_token" => token) : s[:params],
      headers: token ? { "HTTP_X_CSRF_TOKEN" => token } : {}, expect: s[:expect], name: "sign_in")
  end
end
page = definition.csrf_page_or_default
tokens = {}
turns = Array.new(definition.requests.size, 0)
run = lambda do
  definition.requests.each_with_index do |r, i|
    cl = r.signed_in ? signed_in : anonymous
    spec = r.at(turns[i] += 1)
    headers, params = spec.headers, spec.params
    token = r.verb != :get && page && r.csrf != "false" && tokens.fetch(cl) { tokens[cl] = cl.token(page) }
    if token
      headers = headers.merge("HTTP_X_CSRF_TOKEN" => token) if r.csrf == "header"
      params = params.merge("authenticity_token" => token) if r.csrf == "param" && !spec.body
    end
    cl.request(r.verb, spec.path, params: params, body: spec.body, headers: headers, expect: r.expect, name: r.name)
  end
end
if receipt
  skipped = { "mails" => definition.mails.map(&:name), "jobs" => definition.jobs.map(&:name),
    "enqueued_by" => definition.requests.select(&:jobs).map(&:name) }
  File.write(receipt, JSON.pretty_generate("manifest" => definition.manifest, "replayed" => definition.requests.map(&:name),
    "not_replayed" => skipped) + "\n")
end
abort "lowrail-profile: #{file} has no requests" if definition.requests.empty?
10.times { run.call }
Lowrail::Profile.reset if defined?(Lowrail::Profile)
20.times { run.call }
