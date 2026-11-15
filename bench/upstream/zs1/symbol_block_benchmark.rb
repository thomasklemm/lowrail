# frozen_string_literal: true

# ruby-bench micro for ZS1 (docs/upstream/zjit-symbol-block.md): a Symbol block argument sent to a Ruby method
# that yields once and to Array#map (defined in Ruby when a JIT is on) over three elements. Copy to <ruby-bench>/benchmarks/symbol-block/benchmark.rb.
require_relative "../../lib/harness/loader"

def one(x) = yield x

def sends(array)
  i = 0
  while i < 1_000_000
    one(i, &:itself)
    array.map(&:itself)
    i += 1
  end
end

ARRAY = [1, 2, 3].freeze

run_benchmark(20) do
  sends(ARRAY)
end
