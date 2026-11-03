# frozen_string_literal: true

# ruby-bench harness that profiles instead of timing:
#   RAILS_PATH=... AVCPU_LABEL=erubi-rails-interp AVCPU_OUT=DIR \
#     ruby -r.../ruby_bench_harness.rb benchmarks/erubi-rails/benchmark.rb
# AVCPU_WARMUP iterations (default 10), then AVCPU_ITRS profiled ones (default 10).
require File.join(ENV.fetch("RUBY_BENCH_DIR"), "lib/harness")

def run_benchmark(_n, **)
  Integer(ENV.fetch("AVCPU_WARMUP", "10")).times { yield }
  require_relative "profile"
  itrs = Integer(ENV.fetch("AVCPU_ITRS", "10"))
  AvCpu.profile(ENV.fetch("AVCPU_LABEL"), ENV.fetch("AVCPU_OUT"), rails_dir: ENV.fetch("RAILS_PATH"), app_dir: Dir.pwd) do
    itrs.times { yield }
  end
  return_results([0], [1.0]) if respond_to?(:return_results, true)
end
