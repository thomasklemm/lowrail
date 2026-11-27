# frozen_string_literal: true

# Sizes of the pieces of EventReporter#notify and EventReporter::LogSubscriber#emit that a logged SQL query runs
# on Rails main (docs/upstream/test-overhead-2.md, "Attribution"), for script/upstream-bench. Diagnostic only.
#   consumes        the subscriber check notify runs (consumes? -> event_method_for, log_level_satisfied?)
#   emit_check      the same check emit runs again before dispatching (logger, event_method_for, log_level_satisfied?)
#   payload         resolve_payload for the seven keyword arguments StructuredEventSubscriber#sql passes
#   kwargs_debug    EventReporter#debug -> #notify with the same keyword arguments, notify a no-op: the hand-off
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = ActiveSupport::Logger.new(File.open(File::NULL, "w"), level: :debug)
ActiveSupport.event_reporter.debug_mode = true

SUB = ActiveSupport.event_reporter.subscribers.map { |entry| entry[:subscriber] }
  .find { |subscriber| subscriber.is_a?(ActiveRecord::LogSubscriber) }
REPORTER = ActiveSupport.event_reporter
KWARGS = { async: false, name: "Post Load", sql: "SELECT 1", cached: nil, lock_wait: nil, binds: [["id", 1]],
  duration_ms: 0.12 }.freeze
NAME = "active_record.sql"

class Noop < ActiveSupport::EventReporter
  def notify(...) = nil
end
NOOP = Noop.new
NOOP.debug_mode = true

UpstreamBench.report("consumes") { SUB.consumes?(NAME) }
UpstreamBench.report("emit_check") do
  SUB.logger && SUB.send(:log_level_satisfied?, SUB.class.event_method_for(NAME))
end
UpstreamBench.report("payload") { REPORTER.send(:resolve_payload, NAME, nil, false, KWARGS) }
UpstreamBench.report("kwargs_debug") { NOOP.debug(NAME, nil, caller_depth: 2, filter_payload: false, **KWARGS) }
