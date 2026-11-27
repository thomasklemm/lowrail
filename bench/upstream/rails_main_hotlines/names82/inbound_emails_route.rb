# RAILS_PATH=TREE RAILS_ENV=development ruby inbound_emails_route.rb: does an app's own `resources :inbound_emails` still
# draw next to Action Mailbox in a local environment, and which route owns the name inbound_emails?
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  gem "rails", path: ENV.fetch("RAILS_PATH")
  gem "sqlite3"
end
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "active_storage/engine"
require "action_mailbox/engine"

class App < Rails::Application
  config.load_defaults 8.1
  config.eager_load = false
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.root = "/tmp/names82-app"
  config.active_storage.service = :test
  config.hosts.clear
end
ENV["DATABASE_URL"] = "sqlite3::memory:"
require "fileutils"
FileUtils.mkdir_p("/tmp/names82-app/config")
File.write("/tmp/names82-app/config/storage.yml", "test:\n  service: Disk\n  root: /tmp/names82-storage\n")
File.write("/tmp/names82-app/config/routes.rb", ENV.fetch("ROUTES", "Rails.application.routes.draw { resources :inbound_emails, only: %i[index show] }"))
puts "Rails #{Rails.version}, #{Rails.env}"
begin
  App.initialize!
  App.reload_routes!
  routes = App.routes
  route = routes.named_routes[:inbound_emails]
  puts "inbound_emails route: #{route.verb} #{route.path.spec} -> #{route.defaults[:controller]}##{route.defaults[:action]}"
  puts "url_helpers.inbound_emails_path: #{routes.url_helpers.inbound_emails_path}"
  puts "url_helpers.inbound_email_path(1): #{routes.url_helpers.inbound_email_path(1)}"
rescue => e
  puts "#{e.class}: #{e.message.lines.first(3).join.strip}"
end
