# frozen_string_literal: true

# Warm up, then profile with stackprof (cpu or wall, raw) for PROF_ITRS iterations.
# PROF_OUT=path.dump PROF_MODE=cpu PROF_INTERVAL=200 WARMUP_ITRS=10 PROF_ITRS=20
require_relative "../harness/harness-common"
require_relative "../harness/harness-extra"

def run_benchmark(_n, **, &block)
  ensure_global_gem("stackprof") unless defined?(StackProf)
  require "stackprof"
  Integer(ENV.fetch("WARMUP_ITRS", "10")).times(&block)
  GC.start
  out = ENV.fetch("PROF_OUT")
  StackProf.run(out: out, mode: ENV.fetch("PROF_MODE", "cpu").to_sym,
                interval: Integer(ENV.fetch("PROF_INTERVAL", "200")), raw: true, aggregate: true) do
    Integer(ENV.fetch("PROF_ITRS", "20")).times(&block)
  end
  puts "profile: #{out}"
end
