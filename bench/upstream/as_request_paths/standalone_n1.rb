# frozen_string_literal: true

require "active_support"
require "active_support/notifications"
require "benchmark"

fanout = ActiveSupport::Notifications::Fanout.new
module Runtime
  def self.call(name, start, finish, id, payload) = nil
end
fanout.subscribe("event", Runtime, monotonic: true)
instrumenter = ActiveSupport::Notifications::Instrumenter.new(fanout)
payload = {}
run = proc { instrumenter.instrument("event", payload) { } }

10_000.times(&run)
before = GC.stat(:total_allocated_objects)
100_000.times(&run)
puts "objects per call: #{(GC.stat(:total_allocated_objects) - before) / 100_000.0}"
puts "ns per call: #{(Benchmark.realtime { 1_000_000.times(&run) } * 1000).round}"
