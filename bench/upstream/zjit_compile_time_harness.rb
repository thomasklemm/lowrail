# ruby-bench harness that runs ITERS iterations and writes ZJIT compile-time stats to ZC_OUT (bet Z6).
# Copy to ruby-bench/harness/zctime.rb, then in benchmarks/<bench>:
#   ZC_OUT=out.json HARNESS=zctime ITERS=3 ruby --zjit benchmark.rb
require_relative '../lib/harness'
def run_benchmark(_hint, **)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  Integer(ENV.fetch("ITERS", "25")).times { yield }
  wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  out = { "wall_ns" => (wall * 1e9).to_i }
  RubyVM::ZJIT.stats.each { |k, v| out[k.to_s] = v if k.to_s =~ /time_ns|compiled_iseq_count|failed_iseq_count|compiled_side_exit_count|code_region_bytes/ }
  require 'json'
  File.write(ENV.fetch("ZC_OUT"), JSON.generate(out))
  return_results([], [0.001])
end
