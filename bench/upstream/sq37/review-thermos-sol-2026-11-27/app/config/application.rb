require "rails"
require "active_record/railtie"

module SQ37Review
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false
    config.secret_key_base = "review-only-not-a-real-key"
  end
end
