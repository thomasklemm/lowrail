# frozen_string_literal: true

# ruby-bench's default harness loop, recording per-iteration wall and process
# CPU time. Writes {"warmup","bench","cpu_warmup","cpu_bench"} (seconds) to
# RESULT_JSON_PATH. WARMUP_ITRS, MIN_BENCH_ITRS as in the default harness.
require_relative "../harness/harness-common"

def run_benchmark(_n, **, &block)
  require "json" # after the app's Bundler.setup
  warmup = Integer(ENV.fetch("WARMUP_ITRS", "15"))
  itrs = Integer(ENV.fetch("MIN_BENCH_ITRS", "10"))
  wall = []
  cpu = []
  (warmup + itrs).times do
    w0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    c0 = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    block.call
    cpu << Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - c0
    wall << Process.clock_gettime(Process::CLOCK_MONOTONIC) - w0
  end
  File.write(ENV.fetch("RESULT_JSON_PATH"), JSON.dump(
    "warmup" => wall.first(warmup), "bench" => wall.drop(warmup),
    "cpu_warmup" => cpu.first(warmup), "cpu_bench" => cpu.drop(warmup),
    "RUBY_DESCRIPTION" => RUBY_DESCRIPTION,
  ))
  puts "wall #{(1000 * wall.drop(warmup).sum / itrs).round(1)} ms, cpu #{(1000 * cpu.drop(warmup).sum / itrs).round(1)} ms"
end
