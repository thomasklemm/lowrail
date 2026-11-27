# frozen_string_literal: true

# Counts, per census workload request, the calls behind the Rails 8.2 round's leads:
# IsolatedExecutionState reads by caller, connection-pool lookups, query-cache
# lookups and key hashes, and env_config merges. Not a cost measurement.
#   bundle exec ruby count_sites.rb APP   (inside a census app copy, via run_count.sh)
require_relative "../census/harness"

name = ARGV.fetch(0)
RailsCensus.boot(name)

COUNTS = Hash.new(0)

module CountIES
  def [](key)
    loc = caller_locations(1, 1).first
    COUNTS[[:ies, key, "#{loc.path.sub(%r{.*/(active\w+|action\w+|railties)/lib/}, '\1/')}:#{loc.lineno} #{loc.label}"]] += 1
    super
  end
end
ActiveSupport::IsolatedExecutionState.singleton_class.prepend(CountIES)

module CountPool
  def connection_pool
    COUNTS[[:pool, caller_locations(1, 1).first.then { "#{_1.label}" }]] += 1
    super
  end
end
ActiveRecord::Base.singleton_class.prepend(CountPool)

module CountStore
  def [](key) = (COUNTS[[:qc, :hit_lookup]] += 1; super)

  def compute_if_absent(key)
    COUNTS[[:qc, :compute_if_absent, key.is_a?(Array) ? :binds : :sql]] += 1
    super
  end
end
ActiveRecord::ConnectionAdapters::QueryCache::Store.prepend(CountStore)

module CountBuild
  private def build_request(env)
    COUNTS[[:env_merge, env.size, env_config.size]] += 1
    super
  end
end
Rails.application.singleton_class.prepend(CountBuild)

ops = RailsCensus.workloads(name)
ops.each do |op|
  run = -> { op.call.call; RailsCensus.reset_side_effects }
  5.times { run.call }
  COUNTS.clear
  n = 10
  n.times { run.call }
  puts "== #{op.name}"
  COUNTS.sort_by { -_2 }.first(25).each { |k, v| puts format("%8.1f  %s", v.fdiv(n), k.inspect) }
  total = COUNTS.select { _1[0] == :ies }.sum { _2 }
  puts format("%8.1f  total IsolatedExecutionState.[]", total.fdiv(n))
end
