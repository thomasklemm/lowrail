# frozen_string_literal: true

# Where main's extra cost per logged SQL query goes (docs/upstream/test-overhead-2.md, "Attribution"). For
# script/upstream-bench on Rails main: each case logs one find_by at debug with one layer of the path switched
# off, so the difference to the full case is that layer's inclusive cost. A diagnostic, not a fix: the switches
# are prepended no-ops guarded by one global, present (and checked) in every case alike.
#   full       Notifications -> AR::StructuredEventSubscriber#sql -> EventReporter#debug/#notify
#              -> EventReporter::LogSubscriber#emit -> AR::LogSubscriber#sql -> Logger
#   no_format  AR::LogSubscriber#sql returns at once (message formatting and the logger write gone)
#   no_emit    EventReporter::LogSubscriber#emit returns at once (plus its dispatch to #sql)
#   no_report  EventReporter#notify returns at once (event construction and subscriber loop gone)
#   no_event   StructuredEventSubscriber#emit_debug_event returns at once (the reporter call gone)
#   no_sub     AR::StructuredEventSubscriber#sql returns at once (binds, kwargs gone; Notifications dispatch stays)
#   info       logger at info, debug mode off (as config.log_level = :info)
# The app_subscribers cases add the four other framework log subscribers Campfire registers with the event
# reporter (Action Dispatch, Active Storage, Action Controller, Active Job), as real subclasses with their
# real subscription filters, so the per-event filter loop is the size an app has.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.integer :author_id; t.timestamps }
end
class Post < ActiveRecord::Base; end
Post.create!(title: "Hello", author_id: 1)

log = File.open(File::NULL, "w")
DEBUG = ActiveSupport::Logger.new(log, level: :debug)
INFO = ActiveSupport::Logger.new(log, level: :info)

$off = nil
ActiveRecord::LogSubscriber.prepend(Module.new { def sql(event) = $off == :format ? nil : super })
ActiveSupport::EventReporter::LogSubscriber.prepend(Module.new { def emit(event) = $off == :emit ? nil : super })
ActiveSupport::EventReporter.prepend(Module.new { def notify(...) = $off == :report ? nil : super })
ActiveSupport::StructuredEventSubscriber.prepend(Module.new { def emit_debug_event(...) = $off == :event ? nil : super })
ActiveRecord::StructuredEventSubscriber.prepend(Module.new { def sql(event) = $off == :sub ? nil : super })

others = %w[action_dispatch active_storage action_controller active_job].map do |ns|
  klass = Class.new(ActiveSupport::EventReporter::LogSubscriber) { self.namespace = ns }
  [klass.new, klass.subscription_filter]
end
# Set up once per case: upstream-bench runs a case's calls back to back, so after the first call only the
# comparison runs.
$state = nil
setup = ->(apps, off) do
  return if $state == [apps, off]
  $state = [apps, off]
  others.each do |sub, filter|
    ActiveSupport.event_reporter.unsubscribe(sub)
    ActiveSupport.event_reporter.subscribe(sub, &filter) if apps
  end
  $off = off
  ActiveSupport.event_reporter.debug_mode = off != :info
  ActiveRecord::Base.logger = off == :info ? INFO : DEBUG
end

{ "full" => nil, "no_format" => :format, "no_emit" => :emit, "no_report" => :report, "no_event" => :event,
  "no_sub" => :sub, "info" => :info }.each do |name, off|
  [false, true].each do |apps|
    UpstreamBench.report("#{name}#{", app_subscribers" if apps}") do
      setup.(apps, off)
      Post.find_by(id: 1)
    end
  end
end
