# secure_headers shape: delete a default header from the config in on_load(:action_controller); config/initializers shape: delete it in an app initializer.
require "rails"
require "action_controller/railtie"
class App < Rails::Application
  config.root = __dir__; config.eager_load = false; config.logger = Logger.new(nil); config.secret_key_base = "x" * 64
  initializer("gem.secure_headers_shape") do
    ActiveSupport.on_load(:action_controller) { Rails.application.config.action_dispatch.default_headers.delete("X-Frame-Options") }
  end
  initializer("app.config_initializer_shape") { Rails.application.config.action_dispatch.default_headers.delete("X-Content-Type-Options") }
end
App.initialize!
ActionController::Base
h = ActionDispatch::Response.default_headers
puts({ frozen: h.frozen?, x_frame_options_sent: h.key?("X-Frame-Options"), x_content_type_options_sent: h.key?("X-Content-Type-Options") }.inspect)
