require_relative "../lib/harness"

# Local ruby-bench harness: C method calls per iteration, by owner and name.
# Run in the interpreter (no JIT): a :c_call TracePoint counts every call of a
# C method after warmup, whoever made it (Ruby code or C via rb_funcall).
# Writes {"Owner#name" => calls per iteration} to $CFUNC_CALLS_JSON.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 3))

puts RUBY_DESCRIPTION

def run_benchmark(_num_itrs_hint, **, &block)
  raise "run without a JIT" if RubyVM::YJIT.enabled? || (defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
  WARMUP_ITRS.times { block.call }
  counts = Hash.new(0)
  tp = TracePoint.new(:c_call) { |t| counts[[t.defined_class, t.method_id]] += 1 }
  tp.enable { MIN_BENCH_ITRS.times { block.call } }
  per_itr = counts.to_h do |(owner, mid), n|
    name = owner.singleton_class? ? "#{owner.attached_object.inspect}.#{mid}" : "#{owner.name || owner.inspect}##{mid}"
    [name, n.fdiv(MIN_BENCH_ITRS)]
  end
  require "json" # after Bundler.setup: the benchmark may pin another json
  File.write(ENV.fetch("CFUNC_CALLS_JSON"), JSON.pretty_generate(ruby: RUBY_DESCRIPTION, warmup: WARMUP_ITRS,
    itrs: MIN_BENCH_ITRS, per_itr: per_itr.sort_by { -_2 }.to_h) + "\n")
end
