MICRO = {
  "emitting" => -> { er = ActiveSupport.event_reporter; -> { er.emitting?("action_controller.request_started") } },
  "consumes" => -> { s = ActiveSupport.event_reporter.subscribers.find { _1[:subscriber].is_a?(ActionController::LogSubscriber) }[:subscriber]; -> { s.consumes?("action_controller.request_started") } },
  "logger" => -> { s = ActiveSupport.event_reporter.subscribers.find { _1[:subscriber].is_a?(ActionController::LogSubscriber) }[:subscriber]; -> { s.logger } },
  "info" => -> { l = ActionController::Base.logger; -> { l.info? } },
}
