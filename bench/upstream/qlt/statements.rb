# frozen_string_literal: true

# Distinct cached statements after every census workload of an app ran 3 times,
# under the QLT_* settings of config.rb (prepared statements on):
#   QLT_CONFIG=... hx CORPUS APP bundle exec ruby statements.rb APP
require "json"
require_relative "../census/harness"

name = ARGV.fetch(0)
RailsCensus.boot(name)
ops = RailsCensus.workloads(name)
3.times { ops.each { |op| op.call.call; RailsCensus.reset_side_effects } }
pools = ActiveRecord::Base.connection_handler.connection_pool_list(:all)
sizes = pools.to_h { |p| [p.db_config.name, p.connections.sum { _1.instance_variable_get(:@statements)&.length || 0 }] }
puts JSON.generate(app: name, tags: ENV["QLT_TAGS"], workloads: ops.size, statements: sizes)
