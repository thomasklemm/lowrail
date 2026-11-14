# frozen_string_literal: true

# QL1 (spell out "query"/"queries" in the request log line): the per-request
# log_process_action with two queries, as in the PR body. Run with a bundle that
# supplies the Rails tree under test:
#   BUNDLE_GEMFILE=... taskset -c 3 bundle exec ruby --yjit ql_ips.rb
require "action_controller"
require "active_record"
require "active_record/railties/controller_runtime"
require "benchmark/ips"

ActionController::Base.include ActiveRecord::Railties::ControllerRuntime
payload = { view_runtime: 1.2, db_runtime: 0.4, queries_count: 2, cached_queries_count: 0 }
raise "unexpected" unless ActionController::Base.log_process_action(payload).include?("ActiveRecord: 0.4ms (2 queries, 0 cached)")

Benchmark.ips do |x|
  x.report("log_process_action") { ActionController::Base.log_process_action(payload) }
end
