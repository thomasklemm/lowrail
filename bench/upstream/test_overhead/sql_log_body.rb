# frozen_string_literal: true

# One SQL query logged at debug, as a test environment logs every query to log/test.log, against the same
# query with the logger at info (docs/upstream/test-overhead-2.md). For script/upstream-bench, 8-1-stable
# against main.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.integer :author_id; t.timestamps }
end
class Post < ActiveRecord::Base; end
Post.create!(title: "Hello", author_id: 1)

log = File.open(File::NULL, "w")
debug = ActiveSupport::Logger.new(log, level: :debug)
info = ActiveSupport::Logger.new(log, level: :info)

UpstreamBench.report("find_by, logger at debug") do
  ActiveSupport.event_reporter.debug_mode = true
  ActiveRecord::Base.logger = debug
  Post.find_by(id: 1)
end
UpstreamBench.report("find_by, logger at info") do
  ActiveSupport.event_reporter.debug_mode = false # as railties sets it for config.log_level = :info
  ActiveRecord::Base.logger = info
  Post.find_by(id: 1)
end
