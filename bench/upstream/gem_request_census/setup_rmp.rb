# Setup for ir.sh: a minimal production Rails app with rack-mini-profiler's
# Railtie subscribers, outside any profiled request. render_event instruments one
# render_template.action_view event for a Lobsters-style template path.
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "rack-mini-profiler"
class RmpMicro < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
end
Rails.env = "production"
RmpMicro.initialize!
raise "mini profiler not installed" unless Rails.application.middleware.include?(Rack::MiniProfiler)
raise "measuring" if Rack::MiniProfilerRails.should_measure?
IDENTIFIER = "/srv/app/app/views/stories/_listdetail.html.erb"
def render_event = ActiveSupport::Notifications.instrument("render_template.action_view", identifier: IDENTIFIER) {}
