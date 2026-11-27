# frozen_string_literal: true

# The reviewers' repros for HM5: a callback on a value or key changes the receiver between master's two reads.
# Usage: ruby -I HASHIE/lib to_hash_reentrant.rb
require 'hashie'

h = Hashie::Hash.new
v = Object.new
v.define_singleton_method(:is_a?) { |type| h[:x] = 29; super(type) }
v.define_singleton_method(:to_hash) { { old: 13 } }
h[:x] = v
puts "value whose is_a? replaces its entry: #{h.to_hash.inspect}"

h = Hashie::Hash.new
key = Object.new
calls = 0
key.define_singleton_method(:hash) { calls += 1; h.clear if calls == 3; 7 }
h[key] = Hashie::Array[13]
result = begin
  h.to_hash.values.inspect
rescue StandardError => e
  "#{e.class}: #{e.message[0, 40]}"
end
puts "key whose third hash call clears the receiver: #{result}"
