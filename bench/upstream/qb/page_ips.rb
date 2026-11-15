# frozen_string_literal: true

# benchmark-ips over one whole census request, in process (Rack::Test, as the census):
#   [CENSUS_SET=ce2] [PMAP_RAILS=SPEC] bench/upstream/p_map/hx CORPUS APP \
#     bundle exec ruby [--yjit] -I BENCHMARK_IPS_LIB THIS APP WORKLOAD
# page_ips.sh runs it on one pinned core, alternating trees, best of N.
require_relative "../census/harness"
require "benchmark/ips"

name, workload = ARGV
RailsCensus.boot(name)
op = RailsCensus.workloads(name).find { _1.name == workload } or abort "no workload #{workload}"
reset = -> { RailsCensus.reset_side_effects }
Integer(ENV.fetch("QB_WARMUP", "400")).times { op.call.call; reset.call }
jit = -> { RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
before = jit.call
Benchmark.ips do |x|
  x.config(warmup: 2, time: Integer(ENV.fetch("QB_TIME", "5")))
  x.report("#{name} #{workload}") { op.call.call; reset.call }
end
warn "QB compiled_blocks=#{jit.call - before}"
