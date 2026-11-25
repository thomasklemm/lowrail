# usage: bundle exec ruby sendfile_boot.rb [header]
require "rails"
require "action_controller/railtie"
class Mw; def initialize(app) = @app = app; def call(env) = @app.call(env); end
class App < Rails::Application
  config.load_defaults 8.1
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.action_dispatch.x_sendfile_header = ARGV[0] if ARGV[0]
  config.middleware.insert_before Rack::Sendfile, Mw
end
begin
  App.initialize!
  puts "Rails #{Rails.version} header=#{ARGV[0].inspect}: booted, Mw at #{App.middleware.middlewares.index(Mw)}"
rescue Exception => e
  puts "Rails #{Rails.version} header=#{ARGV[0].inspect}: #{e.class}: #{e.message[0, 160]}"
end
