# frozen_string_literal: true

# ruby-bench harness for docs/upstream/combined-effect.md. Like ruby-bench's
# default harness (fixed warmup, then timed iterations), but every iteration
# also records GC runs (major/minor) and allocated objects, read outside the
# timed block. Writes one JSON per process to CE_OUT.
#   CE_OUT=out.json WARMUP_ITRS=10 BENCH_ITRS=20 ruby [--yjit] -Iharness-ce benchmarks/APP/benchmark.rb
# json is required after Bundler.setup (the app may pin another version).
# ruby-bench's common setup (use_gemfile, seeded Random), from the checkout that owns the benchmark.
require File.expand_path("../../harness/harness-common", File.dirname(File.expand_path($PROGRAM_NAME)))

WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 10))
BENCH_ITRS = Integer(ENV.fetch("BENCH_ITRS", 20))

def run_benchmark(_hint, **)
  rows = Array.new(WARMUP_ITRS + BENCH_ITRS) do |i|
    g0 = GC.stat
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    g1 = GC.stat
    row = { "ms" => t * 1000, "gc" => g1[:count] - g0[:count], "major" => g1[:major_gc_count] - g0[:major_gc_count],
      "minor" => g1[:minor_gc_count] - g0[:minor_gc_count],
      "objects" => g1[:total_allocated_objects] - g0[:total_allocated_objects],
      "gc_ms" => g1.fetch(:time, 0) - g0.fetch(:time, 0) }
    puts format("#%-3d %8.1fms gc %3d (major %d) objects %d", i + 1, row["ms"], row["gc"], row["major"], row["objects"])
    row
  end
  require "json"
  yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
  rails = Gem.loaded_specs["railties"]&.full_gem_path
  File.write(ENV.fetch("CE_OUT"), JSON.pretty_generate("ruby" => RUBY_DESCRIPTION, "yjit" => yjit, "rails" => rails,
    "warmup" => WARMUP_ITRS, "iterations" => rows) + "\n")
end
