# frozen_string_literal: true

# Diagnostic ceiling for final-relation tagging: the real relation is still
# built on every call; ONLY Arel/SQL compilation is skipped. No production
# guards, source rewriting, or claims of eligible app sites/hits.
# From a prepared corpus app: ruby --yjit /abs/bench/ar_chain_ceiling.rb
require File.expand_path("config/environment", Dir.pwd)
require "json"
require "active_record/statement_cache"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
abort "YJIT required" unless RubyVM::YJIT.enabled?

case Rails.application.class.module_parent_name
when "Campfire"
  owner = Room.find_by!(name: "All Talk")
  relation = -> { owner.messages.ordered.limit(10) }
when "Pingcrm"
  owner = User.find_by!(email: "m0-inertia@example.test").account
  relation = -> { owner.organizations.not_trashed.order(:name).limit(10) }
else
  abort "use the prepared Campfire or PingCRM corpus"
end

module ARChainCeiling
  private

  def exec_main_query(async: false)
    return super unless (query = @lowrail_bench_query) && !async
    model.with_connection do |connection|
      model._query_by_sql(connection, query[0].sql_for(query[1], connection), query[1],
        preparable: true, allow_retry: query[0].retryable)
    end
  end
end
ActiveRecord::Relation.prepend(ARChainCeiling)

query, binds = relation.call.model.with_connection do |connection|
  connection.cacheable_query(ActiveRecord::StatementCache, relation.call.arel)
end
plain = -> { relation.call.to_a }
cached = -> {
  value = relation.call
  value.instance_variable_set(:@lowrail_bench_query, [query, binds])
  value.to_a
}
# This ceiling binds one owner's fixed ID on purpose. It is not an
# implementation for variable owners/arguments, nor a support test.
abort "different records" unless plain.call.map(&:attributes) == cached.call.map(&:attributes)
cases = { "chain_rails" => plain, "chain_unguarded_sql_only" => cached }
cases = cases.to_a.reverse.to_h if ENV["BENCH_REVERSE"] == "1"
rows = ActiveRecord::Base.uncached do
  cases.map do |name, call|
    1_000.times { call.call }
    GC.start
    count = 0
    objects = GC.stat(:total_allocated_objects)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    deadline = started + Float(ENV.fetch("BENCH_SECONDS", "3"))
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      call.call
      count += 1
    end
    { route: name, us_per_req: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1e6 / count,
      allocs_per_req: (GC.stat(:total_allocated_objects) - objects).fdiv(count) }
  end
end
File.write(ENV.fetch("BENCH_JSON"), JSON.pretty_generate(rows))
puts JSON.pretty_generate(rows)
