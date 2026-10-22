# frozen_string_literal: true

# Untimed server/client separation. Run under each app's frozen bundle.
require "json"
require "digest"
require_relative "../experiments/campfire_scenario"

role, name, app, state = ARGV
app = File.realpath(app)
if role == "prepare" && name == "campfire"
  CampfireScenario.prepare(app, File.expand_path(state))
  exit
end
raise "usage: prepare|calls blog|campfire APP [STATE]" unless role == "calls"
if name == "campfire"
  CampfireScenario.environment(app, state).each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  CampfireScenario.boot(app)
else
  ENV.update("RAILS_ENV" => "production", "RACK_ENV" => "production",
    "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "fatal")
  require File.join(app, "config/application")
  Rails.application.config.yjit = false
  require File.join(app, "config/environment")
end
Rails.application.eager_load!
Rails.logger.level = :fatal
ActiveRecord::Base.logger = nil
load ENV.fetch("TIME_SOURCE")
require "rack/mock"

headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_ACCEPT" => "text/html",
  "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0", "HTTP_X_REQUEST_ID" => "stdlib-time-calls"}
paths = if name == "campfire"
  driver = CampfireScenario::Driver.new(state, record: false, validate: false)
  driver.login
  headers["HTTP_HOST"] = "campfire.example.invalid"
  headers["HTTP_COOKIE"] = driver.instance_variable_get(:@cookies).map { |k, v| "#{k}=#{v}" }.join("; ")
  JSON.parse(File.read(File.join(state, "scenario.json"))).fetch("vector")
    .select { %w[room pagination sidebar search].include?(_1.fetch("id")) }.map { _1.fetch("path") }
else
  ["/articles", "/articles/1", "/articles/1/edit", "/icon.svg"]
end

counts = nil
trace = TracePoint.new(:call) do |event|
  if event.self.equal?(Time) && %i[httpdate rfc2822 parse xmlschema].include?(event.method_id)
    locations = caller_locations(1, 16).map { "#{_1.path}:#{_1.lineno}:#{_1.label}" }
    key = [event.method_id, locations]
    counts[key] += 1
  end
end
rows = paths.flat_map do |path|
  {"ordinary" => {}, "stale_conditional" => {"HTTP_IF_MODIFIED_SINCE" => "Sun, 06 Nov 1994 08:49:37 GMT"},
    "fresh_conditional" => {"HTTP_IF_MODIFIED_SINCE" => "Thu, 01 Jan 2099 00:00:00 GMT"}}.flat_map do |variant, extra|
    %w[server mock_client_included].map do |boundary|
      request = -> {
        settings = headers.merge(extra)
        if boundary == "server"
          env = Rack::MockRequest.env_for(path, settings)
          trace.enable do
            status, _, body = Rails.application.call(env)
            begin
              body.each { |_| }
            ensure
              body.close if body.respond_to?(:close)
            end
            status
          end
        else
          trace.enable { Rack::MockRequest.new(Rails.application).get(path, settings).status }
        end
      }
      counts = Hash.new(0)
      5.times { request.call }
      counts.clear
      statuses = 10.times.map { request.call }
      raise "failed #{path}" unless statuses.all? { [200, 304].include?(_1) }
      {"route" => path, "variant" => variant, "boundary" => boundary, "requests" => 10,
        "statuses" => statuses.tally, "calls" => counts.map { |(method, stack), count|
          {"method" => method, "per_request" => count.fdiv(10), "stack" => stack} }}
    end
  end
end
puts "STDLIB_TIME_CALLS #{JSON.generate(app: name, ruby: RUBY_DESCRIPTION, rails: Rails.version,
  lock_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
  time_sha256: Digest::SHA256.file(ENV.fetch("TIME_SOURCE")).hexdigest, rows: rows)}"
