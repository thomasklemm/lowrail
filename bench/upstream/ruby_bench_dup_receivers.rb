require_relative "../lib/harness"

# Local ruby-bench harness: who receives Kernel#dup, and which initialize_dup /
# initialize_copy their class resolves to. Interpreter only (TracePoint).
# Writes {"Class | initialize_dup owner | initialize_copy owner (C|Ruby)" => calls per iteration}
# to $DUP_JSON.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 15))
MIN_BENCH_ITRS = Integer(ENV.fetch("MIN_BENCH_ITRS", 3))

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  counts = Hash.new(0)
  tp = TracePoint.new(:c_call) do |t|
    next unless t.method_id == :dup && t.defined_class == Kernel
    counts[t.self.class] += 1
  end
  tp.enable { MIN_BENCH_ITRS.times { block.call } }
  where = ->(m) { "#{m.owner}#{m.source_location ? " (Ruby)" : " (C)"}" }
  rows = counts.map do |klass, n|
    special = [Integer, Float, Symbol, NilClass, TrueClass, FalseClass, Rational, Complex].any? { klass <= _1 }
    key = special ? "#{klass} | special" : "#{klass} | #{where.(klass.instance_method(:initialize_dup))} | #{where.(klass.instance_method(:initialize_copy))}"
    [key, n.fdiv(MIN_BENCH_ITRS)]
  end
  require "json"
  File.write(ENV.fetch("DUP_JSON"), JSON.pretty_generate(rows.sort_by { -_2 }.to_h) + "\n")
end
