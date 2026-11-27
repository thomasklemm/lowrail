# frozen_string_literal: true

# Callers (4 frames) of ActiveRecord connection-pool lookups per request in one
# census workload. Not a cost measurement.
#   bundle exec ruby pool_callers.rb APP WORKLOAD   (via run_in_app.rb)
require_relative "../census/harness"

name, workload = ARGV
RailsCensus.boot(name)
COUNTS = Hash.new(0)

module CountPool
  def connection_pool
    stack = caller_locations(1, 5).map { "#{_1.path.sub(%r{.*/(active\w+|action\w+|railties)/lib/}, '\1/').sub(%r{.*/gems/}, '')}:#{_1.lineno}" }
    COUNTS[stack] += 1
    super
  end
end
ActiveRecord::Base.singleton_class.prepend(CountPool)

op = RailsCensus.workloads(name).find { _1.name == workload } or abort "no workload #{workload}"
run = -> { op.call.call; RailsCensus.reset_side_effects }
3.times { run.call }
COUNTS.clear
run.call
COUNTS.sort_by { -_2 }.first(20).each { |k, v| puts "#{v}\n  #{k.join("\n  ")}" }
puts "total #{COUNTS.values.sum}"
