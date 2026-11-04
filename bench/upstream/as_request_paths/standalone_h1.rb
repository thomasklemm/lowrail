# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/hash/slice"
require "benchmark"

options = { "media" => "all" }
run = proc { options.extract!("protocol", "extname", "host", "skip_pipeline") }

10_000.times(&run)
before = GC.stat(:total_allocated_objects)
100_000.times(&run)
puts "objects per call: #{(GC.stat(:total_allocated_objects) - before) / 100_000.0}"
puts "ns per call: #{(Benchmark.realtime { 1_000_000.times(&run) } * 1000).round}"
