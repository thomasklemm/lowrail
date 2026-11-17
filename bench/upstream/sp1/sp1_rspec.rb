# SP1: rspec-rails 8.0.5's feature example group against Rails main, with and without configured default_url_options (CONFIGURE=1).
require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
class App < Rails::Application
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.root = __dir__
  if ENV["CONFIGURE"] == "1"
    config.action_mailer.default_url_options = { host: "cfg.example.com" }
    config.action_controller.default_url_options = { host: "cfg.example.com" }
    routes.default_url_options = { host: "cfg.example.com" }
  end
end
App.initialize!
require "rspec/rails"
puts "rspec-rails #{Gem.loaded_specs["rspec-rails"].version} configure=#{ENV["CONFIGURE"] == "1"} #{ActionPack.method(:version).source_location.first[%r{ips/[^/]+}]}"
begin
  group = RSpec.describe("x", type: :feature) { }
  puts "feature group defined: default_url_options=#{group.default_url_options.inspect}"
rescue => e
  puts "#{e.class}: #{e.message}"
  puts e.backtrace.grep(/feature_example_group/).first
end
