require_relative "../lib/harness"

# Local ruby-bench harness: Rails.cache operations per iteration after warmup.
# Copy into ruby-bench's harness/ and run with HARNESS=ruby_bench_cache_probe.
# Prints the store class, the count and summed duration of every
# cache_*.active_support event per measured iteration, and their share of the
# iteration. Used for docs/upstream/ruby-bench-improvements.md.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 5))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 5))

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  counts = Hash.new(0)
  durations = Hash.new(0.0)
  sub = ActiveSupport::Notifications.subscribe(/\Acache_.*\.active_support\z/) do |name, start, finish, _id, _payload|
    counts[name] += 1
    durations[name] += finish - start
  end
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  MIN_BENCH_ITRS.times { block.call }
  total = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  ActiveSupport::Notifications.unsubscribe(sub)
  puts "store=#{Rails.cache.class} iters=#{MIN_BENCH_ITRS} #{(total / MIN_BENCH_ITRS * 1000).round(1)} ms/iter"
  counts.sort.each do |name, n|
    puts format("  %-36s %7.1f/iter %8.2f ms/iter", name, n.fdiv(MIN_BENCH_ITRS), durations[name] / MIN_BENCH_ITRS * 1000)
  end
  puts format("  cache share of iteration: %.2f%%", durations.values.sum / total * 100)
end
