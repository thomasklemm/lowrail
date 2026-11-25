# AM2: an app that requires action_mailer/railtie but not active_job/railtie (rails new --skip-active-job, or a
# hand-written list). 8.1 loaded the Active Job railtie through Action Mailer's; since #59820 main doesn't.
require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
class App < Rails::Application
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  begin
    config.active_job.queue_adapter = :test
    puts "config.active_job.queue_adapter=: ok"
  rescue NoMethodError => e
    puts "config.active_job.queue_adapter=: #{e.class}"
  end
  config.action_mailer.delivery_method = :test
end
App.initialize!
class Notifier < ActionMailer::Base
  def hello = mail(to: "a@example.com", from: "b@example.com", subject: "hi", body: "x")
end
puts "Rails #{Rails.version}: ActiveJob after boot=#{defined?(ActiveJob).inspect} railtie=#{defined?(ActiveJob::Railtie).inspect}"
begin
  Notifier.hello.deliver_later
  puts "deliver_later: ok, adapter=#{ActiveJob::Base.queue_adapter.class} enqueued=#{ActiveJob::Base.queue_adapter.try(:enqueued_jobs)&.size.inspect}"
rescue => e
  puts "deliver_later: #{e.class}: #{e.message[0, 140]}"
end
