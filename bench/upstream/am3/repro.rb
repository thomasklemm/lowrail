require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
class Repro < Rails::Application
  config.load_defaults 8.1 unless ENV["NO_DEFAULTS"]
  config.eager_load = true
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
end
label = "#{Gem.loaded_specs["railties"].version} #{ENV["NO_DEFAULTS"] ? "no load_defaults" : "load_defaults 8.1"}"
begin
  Rails.application.initialize!
  ActionMailer::Base
  print "#{label}: boot ok"
rescue Exception => e
  puts "#{label}: boot #{e.class}: #{e.message}"
  exit
end
begin
  puts ", delivery_job #{ActionMailer::Base.delivery_job}"
rescue Exception => e
  puts ", delivery_job #{e.class}: #{e.message}"
end
