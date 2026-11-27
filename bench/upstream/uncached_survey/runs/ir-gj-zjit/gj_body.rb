# frozen_string_literal: true

# good_job's dequeue as its scheduler thread runs it: `Rails.application.reloader.wrap { performer.next }` with the
# default advisory-lock strategy, on PostgreSQL, idle (no job) and with one job enqueued, performed and finished.
# For script/upstream-bench with --gems good_job --with rails --with pg. Needs a local PostgreSQL that the current
# user can create databases on.
require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "good_job"
require "erb"
require "logger"

class GJApp < Rails::Application
  config.eager_load = false
  config.logger = ActiveSupport::Logger.new(IO::NULL)
  config.secret_key_base = "x" * 64
  config.active_job.queue_adapter = :good_job
  config.good_job.execution_mode = :external
end
dbdir = Dir.mktmpdir("gj")
Rails.application.config.paths.add "config/database", with: File.join(dbdir, "database.yml")
db = "uncached_survey_gj_#{Process.pid}"
File.write(Rails.application.config.paths["config/database"].first,
  "test:\n  adapter: postgresql\n  database: #{db}\n  pool: 5\n")
Rails.env = "test"
Rails.application.initialize!
ActiveRecord::Base.logger = ActiveSupport::Logger.new(IO::NULL)
ActiveRecord::Tasks::DatabaseTasks.create(ActiveRecord::Base.connection_db_config)
at_exit do
  ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
  ActiveRecord::Tasks::DatabaseTasks.drop(ActiveRecord::Base.connection_db_config)
end
ActiveRecord::Migration.verbose = false
template = File.join(Gem.loaded_specs.fetch("good_job").full_gem_path,
  "lib/generators/good_job/templates/install/migrations/create_good_jobs.rb.erb")
migration_version = "[#{ActiveRecord::Migration.current_version}]"
eval(ERB.new(File.read(template)).result(binding)) # rubocop:disable Security/Eval
CreateGoodJobs.new.migrate(:up)
GoodJob::Job.reset_column_information

class NotifyRecipientsJob < ActiveJob::Base
  def perform(card_id) = card_id
end

performer = GoodJob::JobPerformer.new("*")
poll = -> { Rails.application.reloader.wrap { performer.next } }
poll.call

UpstreamBench.report("dequeue, idle") { poll.call }
UpstreamBench.report("dequeue and perform one job") do
  NotifyRecipientsJob.perform_later(42)
  poll.call
end
