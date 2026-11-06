# Preload: time share of request kinds (GET vs form submissions) and request counts per iteration.
require File.join(ENV.fetch("RUBY_BENCH_DIR"), "lib/harness")

def run_benchmark(_n, **)
  $t = Hash.new(0.0)
  $c = Hash.new(0)
  Browser.prepend(Module.new do
    def request(path, method:, params: nil, **headers)
      key = params&.key?(:_method) ? params[:_method].upcase : method
      key = "#{key} #{path.end_with?('.json') ? 'json' : 'html'}"
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      super
    ensure
      $t[key] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
      $c[key] += 1
    end
  end)
  3.times { yield }
  $t.clear; $c.clear
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  5.times { yield }
  total = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  $t.sort_by { -_2 }.each { |k, v| puts format("%-14s %5d req/itr %5.1f%% of time", k, $c[k] / 5, 100 * v / total) }
  puts "requests/itr #{$c.values.sum / 5}"
end
