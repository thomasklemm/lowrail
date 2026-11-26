require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
class Repro < Rails::Application
  config.load_defaults 8.1
  config.eager_load = ENV["EAGER"] == "1"
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
end
aj = -> { $LOADED_FEATURES.any? { _1.end_with?("/active_job.rb") } ? "loaded" : "not loaded" }
Rails.application.initialize!
a = aj.()
ActionMailer::Base
b = aj.()
ActionMailer::Base.delivery_job
puts "#{Gem.loaded_specs["railties"].full_gem_path[%r{rails[^/]*/railties}]} eager=#{ENV["EAGER"] == "1"}: after initialize! #{a}, after ActionMailer::Base #{b}, after delivery_job #{aj.()}"
