# Run from a Rails checkout's actionmailer dir: bundle exec ruby app_probe.rb
# A Rails app with Action Mailer and without Active Job, as #59820 allows, running an integration test.
$LOAD_PATH.reject! { |path| path.include?("/activejob/") }
ENV["RAILS_ENV"] = "test"
require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"

class ProbeApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.action_mailer.delivery_method = :test
  routes.append { get "/" => proc { ProbeMailer.hello.deliver_now; [200, {}, ["ok"]] } }
end

class ProbeMailer < ActionMailer::Base
  def hello = mail(to: "a@example.com", from: "b@example.com", subject: "hi", body: "x")
end

ProbeApp.initialize!
require "rails/test_help"

class ProbeIntegrationTest < ActionDispatch::IntegrationTest
  test("integration test sends an email") { assert_emails(1) { get "/" }; assert_response :ok }
  test("active job not loaded") { assert_not defined?(ActiveJob) }
end

class ProbeMailerTest < ActionMailer::TestCase
  test("mailer test") { assert_emails(1) { ProbeMailer.hello.deliver_now } }
end
