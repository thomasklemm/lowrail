# frozen_string_literal: true

# Untimed production census. Run ONLY in a disposable, prepared Fizzy copy:
# RAILS_ENV=production SKIP_TELEMETRY=1 SECRET_KEY_BASE_DUMMY=1 LOWRAIL=0 \
# LOWRAIL_FREEZE=1 FREEZE_PROFILE=holders FREEZE_WARM_JOBS=0 FREEZE_REPORT=... \
# RUBYOPT='-I/path/to/lowrail/gem/lib -rlowrail/setup' ruby /path/to/this.rb
# The caller restores the four disposable databases between fresh processes.
raise "production only" unless ENV["RAILS_ENV"] == "production"
raise "explicit contract required" unless ENV["LOWRAIL_FREEZE"] == "1"
raise "disposable app marker required" unless File.file?(".lowrail-freeze-disposable")
destination = File.expand_path(ENV.fetch("FREEZE_REPORT"))
raise "report already exists" if File.exist?(destination)
require File.expand_path("config/boot")
require_relative "../../gem/lib/lowrail/freeze_audit"

session = nil
result = {"format" => 1, "lowrail" => ENV.fetch("LOWRAIL"), "profile" => ENV.fetch("FREEZE_PROFILE"),
  "warm_steps" => [], "outcomes" => [], "scope" => "requests and real perform_now jobs; not Solid Queue worker coverage"}
at_exit do
  result.merge!(session.finish!) if session
  result["workload_exit_ok"] = $!.nil? || (SystemExit === $! && $!.success?)
  result["complete"] = result["outcomes"].size == 10
  result["exception"] = {"class" => $!.class.name, "backtrace" => $!.backtrace} if $! && !(SystemExit === $!)
  File.write(destination, JSON.pretty_generate(result))
  exit 1 if result["workload_exit_ok"] && (!result["complete"] || result["outcomes"].any? { !_1["pass"] } || result.fetch("frozen_error_count", 0).positive?)
end

require File.expand_path("config/environment")
Rails.application.eager_load!
require "rack/mock"
require "action_dispatch/testing/test_request"

# Same runtime definitions in both arms; never install an adapter in the off arm.
%w[guard loader preload_plans templates].each { require "lowrail/#{_1}" }
adapters = %w[Lowrail::Compilation::CachedOptions Lowrail::Compilation::Capture Lowrail::Guard::ModuleHooks
  Lowrail::Guard::ObjectHooks Lowrail::Loader::Evaluation Lowrail::PreloadPlans::Hook Lowrail::Templates::CompiledSource]

account = Account.create!(name: "Freeze census")
user = account.users.create!(name: "Author", email_address: "author@example.invalid", password: "disposable-fixture-password")
reader = account.users.create!(name: "Reader", email_address: "reader@example.invalid", password: "disposable-fixture-password")
login = user.sessions.create!
Current.session = login
bucket = account.buckets.create!(name: "Freeze bucket", creator: user, all_access: true)
bucket.subscribe(reader)
bubble = bucket.bubbles.create!(title: "Freeze scenario", creator: user, status: :published)

cookie_request = ActionDispatch::TestRequest.create
cookie_request.env.merge!(Rails.application.env_config)
cookie_request.cookie_jar.signed[:session_token] = login.signed_id
headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0"}
authenticated = headers.merge("HTTP_COOKIE" => cookie_request.cookie_jar.to_header)
Current.reset
requests = [["health", "/up", headers], ["login", "/session/new", headers],
  ["buckets", "/", authenticated], ["bubbles", "/bubbles", authenticated],
  ["bubble", "/buckets/#{bucket.id}/bubbles/#{bubble.id}", authenticated],
  ["notifications", "/notifications", authenticated], ["events", "/events", authenticated]]
request = ->(path, env) do
  response = Rack::MockRequest.new(Rails.application).get(path, env)
  raise "request did not render successfully" unless response.status == 200 && !response.body.empty?
  {"http_status" => response.status, "body_bytes" => response.body.bytesize}
end
requests.each do |name, path, env|
  request.call(path, env)
  result["warm_steps"] << {"name" => "request:#{name}", "count" => 1}
end

seed_jobs = -> do
  Current.session = login
  due = bucket.bubbles.create!(title: "Due bubble", creator: user, status: :published)
  due.update_columns(auto_pop_at: 2.days.ago)
  abandoned = bucket.bubbles.create!(creator: user, status: :creating)
  abandoned.update_columns(updated_at: 2.days.ago)
  summary = bubble.capture(EventSummary.new).event_summary
  event = summary.events.create!(action: "published", creator: user, bubble: bubble, particulars: {})
  Current.reset
  [due, abandoned, event]
end
jobs = ->(data) do
  due, abandoned, event = data
  [["AutoPopAllDueJob", -> do
    before = Pop.count
    AutoPopAllDueJob.perform_now
    raise "due bubble not popped" unless Pop.exists?(bubble_id: due.id) && Pop.count > before
    {"popped_due_bubble" => true, "pop_delta" => Pop.count - before}
  end], ["RemoveAbandonedCreationsJob", -> do
    RemoveAbandonedCreationsJob.perform_now
    raise "abandoned bubble survived" if Bubble.exists?(abandoned.id)
    {"removed_abandoned_bubble" => true}
  end], ["GenerateNotificationsJob", -> do
    before = Notification.where(event_id: event.id).count
    GenerateNotificationsJob.perform_now(event)
    after = Notification.where(event_id: event.id).count
    raise "reader was not notified" unless after > before && Notification.exists?(event_id: event.id, user_id: reader.id)
    {"notification_delta" => after - before, "reader_notified" => true}
  end]]
end
warm_level = Integer(ENV.fetch("FREEZE_WARM_JOBS"))
if warm_level >= 1
  jobs.call(seed_jobs.call).each do |name, perform|
    perform.call
    result["warm_steps"] << {"name" => "job:#{name}", "count" => 1}
  end
end
job_inputs = seed_jobs.call
if warm_level >= 2
  requests.each do |name, path, env|
    request.call(path, env)
    result["warm_steps"] << {"name" => "populated_request:#{name}", "count" => 1}
  end
end

profile = ENV.fetch("FREEZE_PROFILE")
unless profile == "control"
  holders = [Bubble, User, Bucket, Event, Notification, ApplicationController, ApplicationJob,
    AutoPopAllDueJob, RemoveAbandonedCreationsJob, GenerateNotificationsJob,
    *adapters.map { Lowrail.loaded_constant(_1) || raise("missing adapter definition") }]
  session = Lowrail::FreezeAudit::Session.new(profile: profile, holders: holders,
    roots: [Dir.pwd, *Gem.loaded_specs.values.map(&:full_gem_path)]).start!
end
attempt = ->(name, work) do
  session&.stage(name)
  begin
    result["outcomes"] << {"name" => name, "pass" => true, **work.call}
  rescue StandardError => error
    result["outcomes"] << {"name" => name, "pass" => false, "exception" => error.class.name, "backtrace" => error.backtrace}
  end
end
requests.each { |name, path, env| attempt.call("request:#{name}", -> { request.call(path, env) }) }
jobs.call(job_inputs).each { |name, perform| attempt.call("job:#{name}", perform) }
