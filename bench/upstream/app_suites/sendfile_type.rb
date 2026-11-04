# Does a server- or middleware-set env["sendfile.type"] still turn send_file into X-Sendfile
# when config.action_dispatch.x_sendfile_header is nil (the default)?
require "rails"
require "action_controller/railtie"
require "rack/test"

class App < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.hosts.clear
  config.action_dispatch.x_sendfile_header = nil
  routes.append { get "/file" => "files#show" }
end

# Stands in for a server or front middleware that announces X-Sendfile support.
class AnnounceSendfile
  def initialize(app) = @app = app
  def call(env)
    env["sendfile.type"] = "X-Sendfile"
    @app.call(env)
  end
end
App.config.middleware.insert 0, AnnounceSendfile

class FilesController < ActionController::Base
  def show = send_file(__FILE__)
end

App.initialize!
include Rack::Test::Methods
def app = App

get "/file"
puts "Rails #{Rails::VERSION::STRING}, rack #{Rack.release}"
puts "Rack::Sendfile in stack: #{App.middleware.include?(Rack::Sendfile)}"
puts "X-Sendfile header: #{last_response.headers["X-Sendfile"].inspect}"
puts "body bytes: #{last_response.body.bytesize}"
