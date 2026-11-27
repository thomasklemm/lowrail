# Run from a Rails checkout's actionmailer dir: bundle exec ruby probe.rb
$LOAD_PATH.reject! { |path| path.include?("/activejob/") }
require "action_mailer"
require "action_mailer/test_helper"
require "minitest/autorun"
require "active_support/test_case"

class Mailer < ActionMailer::Base
  def hello = mail(to: "a@example.com", from: "b@example.com", subject: "hi", body: "x")
end
ActionMailer::Base.delivery_method = :test

class ProbeTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  test("assert_emails") { assert_emails(1) { Mailer.hello.deliver_now } }
  test("active job not loaded") { assert_not defined?(ActiveJob) }
end
