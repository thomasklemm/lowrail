# frozen_string_literal: true

# Solid Queue's worker and dispatcher polls as `bin/jobs` runs them (one executor run per poll, polling logs silenced),
# on SQLite, idle and busy: the dispatcher dispatching 10 and 100 due scheduled jobs, the worker claiming 3 ready
# jobs. Each busy op enqueues its jobs first and clears the tables after the poll, the same on both sides.
# For script/upstream-bench with --gems solid_queue --with rails --with sqlite3.
require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "solid_queue"
require "logger"

class SQApp < Rails::Application
  config.eager_load = false
  config.logger = ActiveSupport::Logger.new(IO::NULL)
  config.secret_key_base = "x" * 64
  config.active_job.queue_adapter = :solid_queue
end
dir = Dir.mktmpdir("sq")
Rails.application.config.paths.add "config/database", with: File.join(dir, "database.yml")
File.write(Rails.application.config.paths["config/database"].first,
  "test:\n  adapter: sqlite3\n  database: #{File.join(dir, "queue.sqlite3")}\n  pool: 5\n")
Rails.env = "test"
SolidQueue.silence_polling = true
Rails.application.initialize!
ActiveRecord::Base.logger = ActiveSupport::Logger.new(IO::NULL)
ActiveRecord::Schema.verbose = false
load File.join(Gem.loaded_specs.fetch("solid_queue").full_gem_path,
  "lib/generators/solid_queue/install/templates/db/queue_schema.rb")

class NotifyRecipientsJob < ActiveJob::Base
  def perform(card_id) = card_id
end

worker = SolidQueue::Worker.new(queues: "*", threads: 3, polling_interval: 0.1, name: "survey-worker")
worker.send(:register)
dispatcher = SolidQueue::Dispatcher.new(polling_interval: 1, batch_size: 500, name: "survey-dispatcher")
dispatcher.send(:register)
in_executor = ->(&block) { worker.send(:wrap_in_app_executor, &block) }
clear = -> { [SolidQueue::ReadyExecution, SolidQueue::ClaimedExecution, SolidQueue::Job].each(&:delete_all) }

schedule = lambda do |count|
  later = 1.hour.from_now
  ActiveJob.perform_all_later(count.times.map { NotifyRecipientsJob.new(42).set(wait_until: later) })
  SolidQueue::ScheduledExecution.update_all(scheduled_at: 1.minute.ago)
end

UpstreamBench.report("worker poll, idle") { in_executor.call { worker.send(:poll) } }
UpstreamBench.report("dispatcher poll, idle") { in_executor.call { dispatcher.send(:poll) } }
[10, 100].each do |count|
  UpstreamBench.report("dispatcher poll, #{count} due jobs") do
    schedule.call(count)
    in_executor.call { dispatcher.send(:poll) }
    clear.call
  end
end
UpstreamBench.report("worker claim, 3 jobs") do
  ActiveJob.perform_all_later(3.times.map { NotifyRecipientsJob.new(42) })
  in_executor.call { worker.send(:claim_executions) }
  clear.call
end
