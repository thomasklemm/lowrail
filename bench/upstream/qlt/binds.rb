# frozen_string_literal: true

# Queries, query cache hits and binds per Lobsters story page under the QLT_* settings of config.rb:
#   QLT_CONFIG=... hx CORPUS lobsters bundle exec ruby binds.rb
require_relative "../census/harness"
RailsCensus.boot("lobsters")
op = RailsCensus.workloads("lobsters").find { _1.name == "GET story" }
20.times { op.call.call; RailsCensus.reset_side_effects }
c = Hash.new(0)
ActiveSupport::Notifications.subscribe("sql.active_record") do |*, p|
  next if p[:name] == "SCHEMA"
  c[p[:cached] ? :cached : :db] += 1
  c[:binds] += p[:binds].size
end
10.times { op.call.call; RailsCensus.reset_side_effects }
puts c.transform_values { _1 / 10.0 }.merge(ps: ActiveRecord::Base.with_connection(&:prepared_statements)).inspect
