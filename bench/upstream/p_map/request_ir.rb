# frozen_string_literal: true

# Callgrind instructions per whole request for one census workload, in-process
# (Rack::Test, as the census): warm up, GC.start, GC off (a fixed heap), then N
# requests inside Array#cycle, which request_ir.sh toggles collection on.
#   hx CORPUS APP bundle exec ruby [--yjit] request_ir.rb APP WORKLOAD N
require_relative "../census/harness"

name, workload, n = ARGV
RailsCensus.boot(name)
op = RailsCensus.workloads(name).find { _1.name == workload } or abort "no workload #{workload}"
reset = -> { RailsCensus.reset_side_effects }
Integer(ENV.fetch("PMAP_WARMUP", "200")).times { op.call.call; reset.call }
jit = -> { RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
GC.start
GC.disable
before = [jit.call, GC.stat(:total_allocated_objects)]
[op].cycle(Integer(n)) { |o| o.call.call; reset.call }
after = [jit.call, GC.stat(:total_allocated_objects)]
warn "PMAP compiled_blocks=#{after[0] - before[0]} objects=#{after[1] - before[1]}"
