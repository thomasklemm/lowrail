# frozen_string_literal: true

# Objects and time per ConnectionPool#with, for docs/upstream/gem-census.md.
#   ruby [--yjit] connection_pool_micro.rb CONNECTION_POOL_LIB_DIR
$LOAD_PATH.unshift(File.expand_path(ARGV.fetch(0)))
require "connection_pool"
pool = ConnectionPool.new(size: 1) { Object.new }
N = 100_000
puts RUBY_DESCRIPTION
call = -> { pool.with { |conn| conn } }
1000.times { call.() }
GC.start
GC.disable
before = GC.stat(:total_allocated_objects)
N.times { call.() }
objects = (GC.stat(:total_allocated_objects) - before).fdiv(N)
GC.enable
times = Array.new(7) do
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  N.times { call.() }
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / N * 1e9
end
printf("pool.with { }  %5.2f objects/call %6.0f ns/call (median of 7)\n", objects, times.sort[3])
