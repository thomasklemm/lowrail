# frozen_string_literal: true

# ruby-bench micro for ZS1 (docs/upstream/zjit-symbol-block.md): a Symbol block argument sent to a Ruby method
# that yields once and to Array#map (defined in Ruby when a JIT is on) over three elements. Copy to <ruby-bench>/benchmarks/symbol-block/benchmark.rb.
require_relative "../../lib/harness/loader"

def one(x) = yield x

def sends(i, array)
  one(i, &:itself)
  array.map(&:itself)
end

ARRAY = [1, 2, 3].freeze

# The loop stays outside `sends`: a method that holds the loop is called once per iteration and compiled too late.
run_benchmark(20) do
  i = 0
  while i < 1_000_000
    sends(i, ARRAY)
    i += 1
  end
end
