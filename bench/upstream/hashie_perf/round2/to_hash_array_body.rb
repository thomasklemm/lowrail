# frozen_string_literal: true

# The input thermos-sol found slowest for reading each value once: one key holding a Hashie::Array of 131,072 Integers,
# and a Mash with 100 scalar keys as the many-keys counterpart.
require 'hashie'

HUGE = Hashie::Hash[item: Hashie::Array.new(131_072, 17)]
wide = Hashie::Mash.new((1..100).to_h { |i| ["key#{i}", i] })

UpstreamBench.report('Hash#to_hash, one Array of 131,072') { HUGE.to_hash }
UpstreamBench.report('Mash#to_hash, 100 scalar keys') { wide.to_hash }
