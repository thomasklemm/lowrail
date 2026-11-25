# usage: bundle exec ruby sidekiq_boot.rb [adapter]
require "rails"
require "active_job/railtie"
require "sidekiq"
class App < Rails::Application
  config.load_defaults 8.1
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.active_job.queue_adapter = (ARGV[0] || "sidekiq").to_sym
end
begin
  App.initialize!
  class HelloJob < ActiveJob::Base; def perform; end; end
  puts "Rails #{Rails.version} Sidekiq #{Sidekiq::VERSION}: booted, adapter #{ActiveJob::Base.queue_adapter.class}"
rescue Exception => e
  puts "Rails #{Rails.version} Sidekiq #{Sidekiq::VERSION}: #{e.class}: #{e.message[0, 160]}"
end
