# frozen_string_literal: true

# ruby-bench harness for bet P1: warm up, then sample the benchmark block with
# stackprof (raw stacks) and dump the profile. Copy to ruby-bench's
# harness/ directory and run with HARNESS=lowrail_prof.
#
#   PROF_OUT=out.dump PROF_MODE=cpu PROF_INTERVAL=100 WARMUP_ITRS=10 PROF_ITRS=20 \
#     HARNESS=lowrail_prof ruby [--yjit] benchmarks/railsbench/benchmark.rb
require_relative "../lib/harness"
require_relative "../lib/harness/extra"

ensure_global_gem("stackprof")

def run_benchmark(_n, **, &block)
  require "stackprof"
  Integer(ENV.fetch("WARMUP_ITRS", 10)).times(&block)
  out = ENV.fetch("PROF_OUT")
  itrs = Integer(ENV.fetch("PROF_ITRS", 20))
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  StackProf.run(mode: ENV.fetch("PROF_MODE", "cpu").to_sym, interval: Integer(ENV.fetch("PROF_INTERVAL", 100)),
                raw: true, aggregate: true, out: out) do
    itrs.times(&block)
  end
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  warn "profiled #{itrs} iterations in #{t.round(2)} s (yjit=#{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}) -> #{out}"
end
