# ruby-bench harness (copy to ruby-bench's harness/cgsample.rb): WARMUP_ITRS
# iterations, then one sampled Callgrind window of BENCH_ITRS iterations
# (cg_profile.rb). CG_OUT: the JSON; CG_RAILS: the Rails checkout, for paths.
require_relative "../lib/harness"
require ENV.fetch("CG_PROFILE")

WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 2))
BENCH_ITRS = Integer(ENV.fetch("BENCH_ITRS", 2))

def run_benchmark(_hint, **)
  WARMUP_ITRS.times { yield }
  CgProfile.window(ENV.fetch("CG_OUT"), BENCH_ITRS, rails_root: ENV["CG_RAILS"]) { BENCH_ITRS.times { yield } }
end
