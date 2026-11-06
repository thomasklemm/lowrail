# Deliberate slowdown for the A/B check: every benchmark iteration spins for
# SLOW_PCT percent of its own time on top, so the expected ratio is 1 + SLOW_PCT/100.
module SlowIterations
  PCT = Float(ENV.fetch("SLOW_PCT", "2")) / 100

  def run_benchmark(*args, **kwargs, &block)
    super(*args, **kwargs) do
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = block.call
      t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stop = t1 + (t1 - t0) * PCT
      nil while Process.clock_gettime(Process::CLOCK_MONOTONIC) < stop
      result
    end
  end
end
# Prepend only once the harness has defined run_benchmark: the harness loader skips
# loading the harness when run_benchmark is already defined.
def Object.method_added(name)
  prepend(SlowIterations) if name == :run_benchmark && !ancestors.include?(SlowIterations)
  super
end
