# frozen_string_literal: true

# Request benchmark + profile for a corpus app, run in-process through Rack.
#
#   cd .corpus/real-blog
#   RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 ruby --yjit \
#     /abs/lowrail/bench/requests.rb GET:/articles GET:/articles/1 ...
#
# Env: BENCH_SECONDS (default 5 per route), BENCH_PROFILE=out.json (stackprof
# raw, wall mode), BENCH_JSON=out.json (results). Not part of the app bundle:
# stackprof is put on the load path directly.
# BENCH_HEADERS is a JSON object of Rack headers, e.g.
# '{"HTTP_COOKIE":"session_token=...","HTTP_ACCEPT":"application/json"}'.
# Headers apply to every route; use separate runs for different identities.

stackprof = Gem::Specification.find_by_name("stackprof")
$LOAD_PATH.unshift(*stackprof.full_require_paths)

require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "json"

Rails.application.eager_load!
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil

routes = ARGV.map { |spec| spec.split(":", 2) }
abort "usage: requests.rb VERB:PATH ..." if routes.empty?
seconds = Float(ENV.fetch("BENCH_SECONDS", "5"))
app = Rails.application
session = Rack::MockRequest.new(app)
headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))

def call(session, verb, path, headers)
  res = session.request(verb, path, headers)
  raise "#{verb} #{path} -> #{res.status}" unless (200..299).cover?(res.status)
  res
end

routes.each { |verb, path| 200.times { call(session, verb, path, headers) } } # warm up (YJIT)

results = routes.map do |verb, path|
  GC.start
  n = 0
  alloc0 = GC.stat(:total_allocated_objects)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  deadline = t0 + seconds
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    call(session, verb, path, headers)
    n += 1
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  allocs = (GC.stat(:total_allocated_objects) - alloc0) / n.to_f
  { route: "#{verb} #{path}", requests: n, rps: (n / elapsed).round(1),
    us_per_req: (elapsed / n * 1e6).round(1), allocs_per_req: allocs.round(1) }
end

results.each { |r| puts format("%-28s %8.1f req/s %9.1f us/req %8.1f allocs/req", r[:route], r[:rps], r[:us_per_req], r[:allocs_per_req]) }
puts "YJIT: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}  #{RUBY_DESCRIPTION}"

if (out = ENV["BENCH_PROFILE"])
  require "stackprof"
  profile = StackProf.run(mode: :wall, raw: true, interval: 100) do
    routes.each { |verb, path| (results.find { _1[:route] == "#{verb} #{path}" }[:requests] / seconds * 2).to_i.times { call(session, verb, path, headers) } }
  end
  File.write(out, JSON.generate(profile))
  puts "profile: #{out}"
end
File.write(ENV["BENCH_JSON"], JSON.pretty_generate(results)) if ENV["BENCH_JSON"]
