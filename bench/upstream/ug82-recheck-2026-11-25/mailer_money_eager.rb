require "rails"
require "action_mailer/railtie"
require "money-rails"
class App < Rails::Application
  config.load_defaults 8.1
  config.eager_load = true
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.action_mailer.delivery_method = :test
end
begin; App.initialize!; rescue NoMethodError => e; puts "initialize! raised: #{e.message[0,90]}"; exit; end
class M < ActionMailer::Base
  def hi = mail(to: "a@b", from: "c@d", subject: "s", body: "b")
end
r = (M.hi.deliver_later; "ok") rescue "#{$!.class}: #{$!.message[0, 110]}"
puts "Rails #{Rails.version} money-rails #{Gem.loaded_specs["money-rails"].version}: boot ok, deliver_later #{r}"
