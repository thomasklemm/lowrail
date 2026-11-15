# frozen_string_literal: true

# Per-request query, compile and statement cache counts for one census workload
# under the QLT_* settings of config.rb:
#   QLT_CONFIG=.../config.rb QLT_TAGS=... QLT_PS=... QLT_CACHE=... \
#     hx CORPUS APP bundle exec ruby --yjit probe.rb APP WORKLOAD N
# Prints one JSON line.
require "json"
require_relative "../census/harness"

module QLTProbe
  STATS = Hash.new(0)
  TEXTS = {}
  def self.clock = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

  module SQLite
    def prepare(sql, *)
      t = QLTProbe.clock
      super
    ensure
      STATS[:compiles] += 1
      STATS[:compile_ns] += QLTProbe.clock - t
      TEXTS[sql] = true
    end
  end

  module PG
    def send_prepare(_name, sql, *)
      STATS[:compiles] += 1
      TEXTS[sql] = true
      super
    end

    def send_query_prepared(*)
      STATS[:reuses] += 1
      super
    end

    %i[send_query_params send_query].each do |m|
      define_method(m) do |sql, *args|
        STATS[:compiles] += 1
        STATS[:unprepared] += 1
        TEXTS[sql] = true
        super(sql, *args)
      end
    end
  end
end

name, workload, n = ARGV
n = Integer(n)
RailsCensus.boot(name)
SQLite3::Database.prepend(QLTProbe::SQLite) if defined?(SQLite3::Database)
PG::Connection.prepend(QLTProbe::PG) if defined?(PG::Connection)
op = RailsCensus.workloads(name).find { _1.name == workload } or abort "no workload #{workload}"
reset = -> { RailsCensus.reset_side_effects }

queries = 0
ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  next if payload[:cached] || payload[:name] == "SCHEMA"
  queries += 1
end

pg = ActiveRecord::Base.connection_db_config.adapter == "postgresql"
backend_ns = lambda do
  next 0 unless pg
  pids = ActiveRecord::Base.with_connection { _1.select_values("SELECT pid FROM pg_stat_activity WHERE datname = current_database()") }
  pids.sum { File.read("/proc/#{_1}/schedstat").split.first.to_i rescue 0 }
end

Integer(ENV.fetch("QLT_WARMUP", "100")).times { op.call.call; reset.call }
QLTProbe::STATS.clear
QLTProbe::TEXTS.clear
queries = 0
db0 = backend_ns.call
t0 = QLTProbe.clock
n.times { op.call.call; reset.call }
wall = QLTProbe.clock - t0
db1 = backend_ns.call

pools = ActiveRecord::Base.connection_handler.connection_pool_list(:all)
pool_sizes = pools.flat_map { |p| p.connections.map { _1.instance_variable_get(:@statements)&.length || 0 } }
sample = QLTProbe::TEXTS.keys.find { _1.include?("/*") } || QLTProbe::TEXTS.keys.first
s = QLTProbe::STATS
puts JSON.generate(
  app: name, workload: workload, tags: ENV["QLT_TAGS"], ps: ENV["QLT_PS"], cache: ENV["QLT_CACHE"],
  prepared_statements: ActiveRecord::Base.with_connection(&:prepared_statements), yjit: RubyVM::YJIT.enabled?,
  queries: (queries.to_f / n).round(2), compiles: (s[:compiles].to_f / n).round(2), reuses: (s[:reuses].to_f / n).round(2),
  unprepared: (s[:unprepared].to_f / n).round(2), compile_us: (s[:compile_ns] / 1000.0 / n).round(1),
  distinct_sql: QLTProbe::TEXTS.size, statement_pools: pool_sizes,
  wall_us: (wall / 1000.0 / n).round(1), db_backend_us: (pg ? ((db1 - db0) / 1000.0 / n).round(1) : nil),
  sample: sample&.slice(0, 300)
)
