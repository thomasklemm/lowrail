# SP1: default_url_options frozen unless configured, on the Rails checkout the bundle points at. CONFIGURE=1 sets both configs.
require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
class App < Rails::Application
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  if ENV["CONFIGURE"] == "1"
    config.action_mailer.default_url_options = { host: "cfg.example.com" }
    config.action_controller.default_url_options = { host: "cfg.example.com" }
  end
end
App.initialize!
App.routes.draw { get "/posts" => "posts#index", as: :posts }
class PostsController < ActionController::Base; def index = head(:ok); end
class UrlThing; include App.routes.url_helpers; end
class OverrideMailer < ActionMailer::Base
  def default_url_options = { host: "override.example.com" }
  def hello = mail(to: "a@b.c", from: "a@b.c", subject: "x") { |f| f.text { render plain: posts_url } }
end
def probe(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message}"
end
puts "rails #{Rails.gem_version} #{Rails.root ? "" : ""}#{ActionPack.method(:version).source_location.first[%r{ips/[^/]+}]} configure=#{ENV["CONFIGURE"] == "1"}"
{ "ActionMailer::Base" => ActionMailer::Base, "ActionController::Base" => ActionController::Base, "PostsController.new" => PostsController.new, "UrlThing" => UrlThing, "UrlThing.new" => UrlThing.new }.each do |name, o|
  probe("#{name}.default_url_options frozen?") { [o.default_url_options, o.default_url_options.frozen?] }
end
session = ActionDispatch::Integration::Session.new(App)
probe("integration session default_url_options") { [session.default_url_options, session.default_url_options.frozen?] }
probe("ActionMailer::Base.default_url_options[:host] =") { ActionMailer::Base.default_url_options[:host] = "shop.example.com" }
probe("UrlThing.default_url_options[:host] =") { UrlThing.default_url_options[:host] = "x.example.com" }
probe("routes.default_url_options frozen? and []=") { [App.routes.default_url_options.frozen?, (App.routes.default_url_options[:host] = "r.example.com")] }
probe("assign new Hash to mailer") { ActionMailer::Base.default_url_options = { host: "new.example.com" }; ActionMailer::Base.default_url_options }
probe("override method mail url") { OverrideMailer.hello.body.to_s }
