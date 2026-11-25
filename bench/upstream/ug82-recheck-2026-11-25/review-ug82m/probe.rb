require "rails"

mode = ARGV.fetch(0)
abort "RAILS_ENV must be test or production" unless %w[test production].include?(ENV["RAILS_ENV"])
if mode == "all"
  require "rails/all"
else
  require "active_job/railtie" if mode.include?("explicit")
  require "action_mailer/railtie"
end
require "money-rails" if mode.start_with?("money")

class ReviewApp < Rails::Application
  config.load_defaults 8.1
  config.eager_load = ARGV.fetch(0).include?("eager")
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.action_mailer.delivery_method = :test
end

phase = "configuration"
begin
  ReviewApp.config.active_job.queue_adapter = :inline if mode == "configured"
  phase = "initialize!"
  ReviewApp.initialize!
  puts "boot=ok active_job_railtie=#{!!defined?(ActiveJob::Railtie)} config_active_job=#{ReviewApp.config.respond_to?(:active_job)}"

  if mode == "direct"
    require "active_job"
    ActiveJob::Base.queue_adapter = :inline
  end

  phase = "mailer_class_load"
  class ReviewMailer < ActionMailer::Base
    def greeting
      mail(to: "to@example.org", from: "from@example.org", subject: "review", body: "review body")
    end
  end

  phase = "deliver_later"
  job = ReviewMailer.greeting.deliver_later
  adapter = ReviewMailer.delivery_job.queue_adapter
  puts "enqueue=#{job.successfully_enqueued?} adapter=#{adapter.class.name}"
  adapter.shutdown if adapter.respond_to?(:shutdown)
  puts "deliveries=#{ActionMailer::Base.deliveries.size}"
  if mode.start_with?("money")
    serializers = ReviewApp.config.active_job.custom_serializers
    puts "money_version=#{Gem.loaded_specs.fetch('money-rails').version} serializer_registered=#{serializers.include?(MoneyRails::ActiveJob::MoneySerializer)}"
  end
rescue StandardError => error
  puts "phase=#{phase} error=#{error.class.name}: #{error.message.lines.first.strip}"
  puts error.backtrace.first(10)
  exit 1
end
