# RAILS_PATH=TREE ruby controller_view_collisions.rb: an app's own controller or helper method with the name of a new
# private Rails method (controller_scope, controller_action_scope, scope_prefix, origin_trusted?, ...), through real
# requests.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  gem "rails", path: ENV.fetch("RAILS_PATH")
end
require "action_controller/railtie"
require "action_view/railtie"
require "rack/test"

class App < Rails::Application
  config.load_defaults 8.1
  config.eager_load = false
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.root = "/tmp/names82-cv"
  config.hosts.clear
  config.action_controller.allow_forgery_protection = true
  config.action_dispatch.show_exceptions = :none
end
require "fileutils"
%w[widgets plain_widgets].each do |dir|
  FileUtils.mkdir_p("/tmp/names82-cv/app/views/#{dir}")
  File.write("/tmp/names82-cv/app/views/#{dir}/show.html.erb", %(<%= t(".title", default: "missing") %>|<%= distance_of_time_in_words(0, 3600) %>))
end
App.initialize!
I18n.backend.store_translations(:en, posts: { index: { title: "Posts" } }, widgets: { show: { title: "Widget" } })
App.routes.draw do
  get "/posts" => "posts#index"
  post "/posts" => "posts#create"
  get "/widgets/:id" => "widgets#show"
  post "/plain" => "plain#create"
  get "/plain_widgets/:id" => "plain_widgets#show"
end

module ScopingHelper
  def scope_prefix = "admin"
  def distance_translation(*) = "app"
end

class PostsController < ActionController::Base
  def index = render(plain: t(".title"))
  def create = render(plain: "created")

  private
    def controller_scope = Object # e.g. an authorization scope
    def origin_trusted? = false
end

class WidgetsController < ActionController::Base
  helper ScopingHelper
  def show = render(:show)
end

class PlainController < ActionController::Base
  def create = render(plain: "created")
end

class PlainWidgetsController < ActionController::Base
  def show = render(:show)
end
I18n.backend.store_translations(:en, plain_widgets: { show: { title: "Widget" } })

include Rack::Test::Methods
def app = App
def run(label)
  r = yield
  body = r.status == 500 ? last_request.env["action_dispatch.exception"]&.then { "#{_1.class}: #{_1.message.lines.first.strip}" } : r.body[0, 120]
  puts "#{label} => #{r.status} #{body.inspect}"
rescue Exception => e
  puts "#{label} => #{e.class}: #{e.message.lines.first.strip}"
end
puts "Rails #{Rails.version}"
run("controller with private controller_scope: t('.title')") { get "/posts" }
run("controller with private origin_trusted?: POST without token") { post "/posts", {}, "HTTP_SEC_FETCH_SITE" => "same-origin", "HTTP_ORIGIN" => "http://example.org" }
run("control, no override: POST without token") { post "/plain", {}, "HTTP_SEC_FETCH_SITE" => "same-origin", "HTTP_ORIGIN" => "http://example.org" }
run("control, no override: POST without token, cross-site") { post "/plain", {}, "HTTP_SEC_FETCH_SITE" => "cross-site", "HTTP_ORIGIN" => "http://evil.example" }
run("controller with private origin_trusted?: POST without token, cross-site") { post "/posts", {}, "HTTP_SEC_FETCH_SITE" => "cross-site", "HTTP_ORIGIN" => "http://evil.example" }
run("control, no helper override: view") { get "/plain_widgets/1" }
run("view with helper scope_prefix and distance_translation") { get "/widgets/1" }
