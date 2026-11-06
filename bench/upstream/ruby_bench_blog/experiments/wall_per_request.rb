# Preload: WARM iterations, then ITRS timed iterations; per request kind wall ms per iteration.
# Prints one JSON line to OUT. Env: WARM (default 30), ITRS (default 20), OUT.
require File.join(ENV.fetch("RUBY_BENCH_DIR"), "lib/harness")
require "json"

def run_benchmark(_n, **)
  ENV.fetch("WARM", "30").to_i.times { yield }
  times = Hash.new(0.0)
  Browser.prepend(Module.new do
    define_method(:request) do |path, method:, params: nil, **headers|
      verb = params&.key?(:_method) ? params[:_method].upcase : method
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = super(path, method: method, params: params, **headers)
      times["#{verb} #{path.gsub(/\d+/, ":id")} #{result[0]}"] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
      result
    end
  end)
  n = ENV.fetch("ITRS", "20").to_i
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { yield }
  total = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  per = times.transform_values { 1000 * _1 / n }
  writes = per.sum { |k, v| k.start_with?("GET") ? 0 : v }
  reads = per.sum { |k, v| k.start_with?("GET") ? v : 0 }
  File.write(ENV.fetch("OUT"), JSON.dump(desc: RUBY_DESCRIPTION, total_ms: 1000 * total / n, reads_ms: reads, writes_ms: writes, kinds: per) + "\n")
end
