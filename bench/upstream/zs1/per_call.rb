# frozen_string_literal: true

# Per-call cost of a Symbol block argument send for ZS1 (docs/upstream/zjit-symbol-block.md).
#   valgrind --tool=callgrind ruby --zjit per_call.rb CASE N
# Run a case with two values of N and divide the difference in total Ir by the difference in N: startup,
# compilation and warmup cancel out.
def one(x) = yield x

def iseq_symbol(n) = (i = 0; (one(i, &:itself); i += 1) while i < n)
def iseq_literal(n) = (i = 0; (one(i) { |x| x.itself }; i += 1) while i < n)
# Array#map is defined in Ruby when a JIT is on, so it is an ISEQ callee too; Array#sum is a C function.
def map_symbol(n, a = ARRAY) = (i = 0; (a.map(&:itself); i += 1) while i < n)
def map_literal(n, a = ARRAY) = (i = 0; (a.map { |x| x.itself }; i += 1) while i < n)
def sum_symbol(n, a = ARRAY) = (i = 0; (a.sum(&:itself); i += 1) while i < n)
def sum_literal(n, a = ARRAY) = (i = 0; (a.sum { |x| x.itself }; i += 1) while i < n)
def empty(n) = (i = 0; (i += 1) while i < n)

ARRAY = [1, 2, 3].freeze
name, n = ARGV[0], Integer(ARGV[1])
100.times { send(name, 50) }
send(name, n)
