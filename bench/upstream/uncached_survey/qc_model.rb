# frozen_string_literal: true

# What the query cache costs one query that it can never answer: one executor run with Active Record's query-cache
# hooks, one SELECT inside it, as a poll loop runs it. The side named "uncached" runs the query under `uncached`.
# Sides are two empty directories named base, base2 and uncached; script/upstream-bench passes the side's
# directory in UPSTREAM_BENCH_TREE (run with --gems "" --with activerecord --with sqlite3, or with --gems activesupport,activemodel,activerecord and side directories that link those to a Rails checkout).
require "active_record"
require "logger"

uncached = File.basename(ENV.fetch("UPSTREAM_BENCH_TREE")) == "uncached"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:items) { |t| t.integer :channel_hash, limit: 8; t.string :name; t.timestamps }
end
class Item < ActiveRecord::Base; end
now = Time.utc(2026, 11, 27)
Item.insert_all(20.times.map { |i| { channel_hash: i, name: "item #{i}", created_at: now, updated_at: now } })

executor = Class.new(ActiveSupport::Executor)
ActiveRecord::QueryCache.install_executor_hooks(executor)
run = if uncached
  ->(&q) { executor.wrap { Item.uncached(&q) } }
else
  ->(&q) { executor.wrap(&q) }
end

[1, 20, 100].each do |n|
  hashes = (1_000..1_000 + n - 1).to_a
  UpstreamBench.report("#{n} binds, no rows") { run.call { Item.where(channel_hash: hashes).to_a } }
end
rows = (0...20).to_a
UpstreamBench.report("20 binds, 20 rows") { run.call { Item.where(channel_hash: rows).to_a } }
