require "rails"
require "active_record/railtie"

module SQ37Probe
  class Application < Rails::Application
    config.load_defaults 8.2
    config.eager_load = false
    config.secret_key_base = "sq37-public-test-only"
    config.active_support.deprecation = :stderr
    config.active_record.check_schema_cache_dump_version = !ENV["SQ37_SCHEMA_CACHE"]
    config.logger = Logger.new($stdout)
  end
end
