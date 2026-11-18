require_relative "../lib/harness"

# ruby-bench harness (copy to harness/zraise.rb): counts exceptions raised per iteration by class and
# raising frame, to attribute ZJIT's exit_exception_handler. Run without JIT; writes $RAISE_JSON.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 5))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 3))

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  counts = Hash.new(0)
  tp = TracePoint.new(:raise) do |t|
    loc = caller_locations(1, 2).map { |l| "#{l.path.sub(%r{.*/gems/}, "")}:#{l.lineno}:#{l.label}" }.join(" < ")
    counts["#{t.raised_exception.class} #{loc}"] += 1
  end
  tp.enable { MIN_BENCH_ITRS.times { block.call } }
  require "json"
  per = counts.sort_by { -_2 }.to_h { |k, v| [k, v.fdiv(MIN_BENCH_ITRS)] }
  File.write(ENV.fetch("RAISE_JSON"), JSON.pretty_generate(total: per.values.sum, sites: per) + "\n")
end
