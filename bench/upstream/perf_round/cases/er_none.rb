$LOAD_PATH.unshift(*%w[activesupport actionview actionpack].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "action_controller"
require "action_controller/log_subscriber"
ActionController::Base.logger = ActiveSupport::Logger.new(IO::NULL, level: :info)
SUBSCRIBER = ActiveSupport.event_reporter.subscribers.find { _1[:subscriber].is_a?(ActionController::LogSubscriber) }[:subscriber]
MICRO = {
  "consumes" => -> { -> { SUBSCRIBER.consumes?("action_controller.request_started") } },
  "emitting" => -> { -> { ActiveSupport.event_reporter.emitting?("action_controller.request_started") } },
}
