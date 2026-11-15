# frozen_string_literal: true

# benchmark-ips of one whole census request under the QLT_* settings of config.rb:
#   QLT_CONFIG=... QLT_TAGS=... QLT_PS=... QLT_CACHE=... \
#     hx CORPUS APP taskset -c 1 bundle exec ruby --yjit -I BENCHMARK_IPS_LIB ips.rb APP WORKLOAD
require_relative "../census/harness"
require "benchmark/ips"

name, workload = ARGV
RailsCensus.boot(name)
op = RailsCensus.workloads(name).find { _1.name == workload } or abort "no workload #{workload}"
reset = -> { RailsCensus.reset_side_effects }
200.times { op.call.call; reset.call }

Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)
  x.report("#{workload} #{ENV["QLT_TAGS"]} ps=#{ENV["QLT_PS"]} cache=#{ENV["QLT_CACHE"]}") { op.call.call; reset.call }
end
