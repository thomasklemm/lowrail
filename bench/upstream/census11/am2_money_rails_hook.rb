# AM2 x money-rails: money-rails' on_load(:active_job) hook reads Rails.application.config.active_job.
# App requires action_mailer/railtie, not active_job/railtie; deliver_later loads ActiveJob::Base later.
rails = ENV["RAILS"]
rails && %w[activesupport activemodel activerecord actionview actionpack actionmailer activejob railties].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
ActiveSupport.on_load(:active_job) do
  # the shape of money-rails 2.0 lib/money-rails/hooks.rb:39-46
  Rails.application.config.active_job.tap { |c| c.custom_serializers << Object }
  puts "hook: ok"
end
class App < Rails::Application
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.action_mailer.delivery_method = :test
end
App.initialize!
class Notifier < ActionMailer::Base
  def hello = mail(to: "a@example.com", from: "b@example.com", subject: "hi", body: "x")
end
puts "Rails #{Rails.version}: ActiveJob after boot=#{defined?(ActiveJob::Base).inspect}"
begin
  Notifier.hello.deliver_later
  puts "deliver_later: ok"
rescue => e
  puts "deliver_later: #{e.class}: #{e.message[0, 160]}"
end
