# AM4 differential probe: which enqueued-email helpers ActionMailer::TestCase and
# ActionDispatch::IntegrationTest get, and what capture_emails returns for
# deliver_later, in one setup per process.
#   BUNDLE_GEMFILE=gemfiles/TREE/Gemfile ruby probe.rb SCENARIO
require "bundler/setup"

scenario = ARGV.fetch(0)
helper_early = scenario.end_with?("+helper-first")

case scenario.delete_suffix("+helper-first")
when "plain-mailer"
  require "action_mailer"
when "plain-mailer+job"
  require "action_mailer"
  require "active_job"
when "app-all", "app-mailer-only"
  require "rails"
  require "active_job/railtie" if scenario.start_with?("app-all")
  require "action_mailer/railtie"
  require "action_controller/railtie"
  require "action_mailer/test_helper" if helper_early
  class ProbeApp < Rails::Application
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.secret_key_base = "x" * 64
    config.active_job.queue_adapter = :test if config.respond_to?(:active_job)
  end
  ProbeApp.initialize!
else
  abort "unknown scenario"
end

out = { scenario: scenario }
begin
  require "action_mailer/test_case"
  require "action_dispatch/testing/integration" if defined?(Rails::Application)
rescue LoadError => e
  out[:load_error] = e.message
  puts out.inspect
  exit
end

ActionMailer::Base.delivery_method = :test
class ProbeMailer < ActionMailer::Base
  default from: "a@example.com"
  def welcome = mail(to: "b@example.com", subject: "hi", body: "x")
end

methods = %i[assert_emails capture_emails assert_enqueued_emails assert_enqueued_email_with
  assert_no_enqueued_emails deliver_enqueued_emails perform_enqueued_jobs assert_enqueued_jobs]
out[:test_case] = methods.select { |m| ActionMailer::TestCase.method_defined?(m) }
if defined?(ActionDispatch::IntegrationTest)
  ActiveSupport.run_load_hooks(:action_dispatch_integration_test, ActionDispatch::IntegrationTest) unless ActionDispatch::IntegrationTest < ActionMailer::TestHelper
  out[:integration] = methods.select { |m| ActionDispatch::IntegrationTest.method_defined?(m) }
end
out[:helper_ancestors] = ActionMailer::TestHelper.ancestors.map(&:name).first(4)

test = Class.new(ActionMailer::TestCase) { tests ProbeMailer; def test_x; end }.new("test_x")
begin
  test.before_setup
  ProbeMailer.welcome.deliver_now
  later = test.capture_emails { ProbeMailer.welcome.deliver_later }
  out[:capture_deliver_later] = later.size
  now = test.capture_emails { ProbeMailer.welcome.deliver_now }
  out[:capture_deliver_now] = now.size
  if test.respond_to?(:assert_enqueued_emails)
    test.assert_enqueued_emails(1) { ProbeMailer.welcome.deliver_later }
    out[:assert_enqueued_emails] = :ok
  end
rescue Exception => e
  out[:error] = "#{e.class}: #{e.message[0, 120]}"
ensure
  test.after_teardown rescue nil
end
puts out.inspect
