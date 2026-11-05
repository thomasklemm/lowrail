# RAILS=path SIDEKIQ=7.3.10 ruby sidekiq7_adapter_boot.rb -> boots a minimal app with
# config.active_job.queue_adapter = :sidekiq and loads ActiveJob::Base, as Gumroad's development and production do.
# 8-1: Rails' own SidekiqAdapter, boots. Main (adapter removed): Sidekiq 7.x defines its adapter in an
# on_load(:active_job) hook that runs after Active Job's own, so NameError. SIDEKIQ=8.1.7 boots on both.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[railties activejob actionpack actionview activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
  gem "sidekiq", ENV.fetch("SIDEKIQ", "7.3.10")
end
require "rails"
require "active_job/railtie"
require "sidekiq"
require "sidekiq/rails"
class App < Rails::Application
  config.load_defaults 8.1
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.active_job.queue_adapter = :sidekiq
end
begin
  App.initialize!
  ActiveJob::Base
  puts "#{Rails.version}, sidekiq #{Sidekiq::VERSION}: #{ActiveJob::Base.queue_adapter.class}"
  exit 0
rescue NameError => error
  puts "#{Rails.version}, sidekiq #{Sidekiq::VERSION}: #{error.class}: #{error.message.lines.first.strip}"
  exit 1
end
