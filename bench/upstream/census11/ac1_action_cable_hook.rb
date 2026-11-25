# AC1: is the :action_cable load hook run by boot (8.1) or only when ActionCable.server is first used (main)?
require "rails"
require "action_controller/railtie"
require "action_cable/engine"
class App < Rails::Application
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.action_cable.mount_path = ENV["MOUNT"] == "0" ? nil : "/cable"
end
ran = false
ActiveSupport.on_load(:action_cable) { ran = true }
App.initialize!
App.routes.routes.to_a # draw routes, as the first request would
puts "Rails #{Rails.version} mount=#{App.config.action_cable.mount_path.inspect}: hook after boot+routes=#{ran} server_base_loaded=#{!!defined?(ActionCable::Server::Base)}"
