# frozen_string_literal: true

# Preloaded with -r under YJIT by ruby_bench_ir.rb. Ir per iteration is the
# difference between a run with WARMUP_ITRS + JIT_COUNTS_FROM iterations and a
# longer run, so the measured window is the long run's later iterations. This
# snapshots YJIT's compile and invalidation counters in the same process
# before that window and after its last iteration, and writes both to
# JIT_COUNTS_PATH. Equal snapshots mean nothing compiled or invalidated while
# measuring (the JIT-flat check in docs/bench.md).
if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? && ENV["JIT_COUNTS_PATH"]
  module JitCounts
    KEYS = %i[compiled_iseq_count compiled_block_count invalidation_count].freeze
    def self.snap = RubyVM::YJIT.runtime_stats.slice(*KEYS)

    def self.wrap(obj, orig, args, kwargs, blk)
      first = Integer(ENV.fetch("WARMUP_ITRS")) + Integer(ENV.fetch("JIT_COUNTS_FROM", "1")) + 1
      n = 0
      before = after = nil
      orig.bind_call(obj, *args, **kwargs) do
        n += 1
        before = snap if n == first
        result = blk.call
        after = snap if before
        result
      end
    ensure
      File.write(ENV["JIT_COUNTS_PATH"], { before: before, after: after, iterations: n }.to_s + "\n")
    end
  end

  # ruby-bench's harness defines run_benchmark at the top level after this loads.
  def Object.method_added(name)
    return super unless equal?(Object) && name == :run_benchmark && !@jit_counts_wrapped
    @jit_counts_wrapped = true
    orig = instance_method(:run_benchmark)
    define_method(:run_benchmark) { |*args, **kwargs, &blk| JitCounts.wrap(self, orig, args, kwargs, blk) }
    private :run_benchmark
  end
end
