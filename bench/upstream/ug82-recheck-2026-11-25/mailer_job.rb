# usage: bundle exec ruby mailer_job.rb [config|plain|test]
require "rails"
require "action_mailer/railtie"
mode = ARGV[0] || "config"
class App < Rails::Application
  config.load_defaults 8.1
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
end
App.config.active_job.queue_adapter = :inline if mode == "config" rescue (puts "Rails #{Rails.version} #{mode}: config.active_job raised #{$!.class}: #{$!.message[0, 100]}"; exit)
App.initialize!
class M < ActionMailer::Base
  def hi = mail(to: "a@b", from: "c@d", subject: "s", body: "b")
end
r = (M.hi.deliver_later; "delivered via #{ActionMailer::MailDeliveryJob.queue_adapter.class}") rescue "#{$!.class}: #{$!.message[0, 100]}"
puts "Rails #{Rails.version} #{mode}: defined?(ActiveJob::Railtie)=#{!!defined?(ActiveJob::Railtie)} deliver_later: #{r}"
