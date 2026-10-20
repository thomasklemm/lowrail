require_relative "boot"
require "rails"
require "action_controller/railtie"
require "rails_vite"
require "inertia_rails"
require "vite_ruby"
ViteRuby::Builder

module DigestApp
  class Application < Rails::Application
    config.load_defaults 8.1
    config.root = File.expand_path("..", __dir__)
    config.eager_load = true
    config.secret_key_base = "public-fixture-secret-key-base-" * 4
    config.hosts.clear
    config.logger = Logger.new(File::NULL)
    config.cache_store = :memory_store
    config.action_controller.allow_forgery_protection = false
    config.action_dispatch.show_exceptions = :none
  end
end

RailsVite.config.auto_build = false
