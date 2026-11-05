# Can an app still set the host by mutating default_url_options in place when no
# config.action_mailer.default_url_options is configured? Spree's BaseMailer does
# `ActionMailer::Base.default_url_options[:host] = host_url` before every mail.
# Run with a bundle that has the Rails under test, e.g.
#   BUNDLE_GEMFILE=path/to/Gemfile bundle exec ruby mailer_url_options.rb
require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"

class App < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.action_mailer.delivery_method = :test
  routes.append { get "/products/:id" => "products#show", as: :product }
end
App.initialize!

class ShopMailer < ActionMailer::Base
  include App.routes.url_helpers

  def receipt
    ActionMailer::Base.default_url_options[:host] = "shop.example"
    mail(to: "a@example.com", from: "b@example.com", subject: "Receipt", body: product_url(1))
  end
end

def attempt(label)
  puts "#{label}: #{yield.inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message}"
end

puts "Rails #{Rails::VERSION::STRING}"
attempt("ActionMailer::Base.default_url_options.frozen?") { ActionMailer::Base.default_url_options.frozen? }
attempt("mail body after mutating ActionMailer::Base.default_url_options") { ShopMailer.receipt.body.to_s }
attempt("ActionController::Base.default_url_options[:host] = ...") { ActionController::Base.default_url_options[:host] = "shop.example" }
attempt("routes.default_url_options[:host] = ... (RouteSet, not frozen by #58483)") { App.routes.default_url_options[:host] = "shop.example" }
attempt("reassigning ActionMailer::Base.default_url_options") do
  ActionMailer::Base.default_url_options = ActionMailer::Base.default_url_options.merge(host: "shop.example")
  ShopMailer.receipt.body.to_s
end
