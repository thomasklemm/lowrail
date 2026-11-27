# frozen_string_literal: true

# Cost of LazyIndexedAttributeSet#keys (main) against variants defined here, on a
# loaded record whose attributes are all built (as after a save) and one untouched.
require "benchmark/ips"
require_relative "setup_model"

class ActiveModel::LazyIndexedAttributeSet
  # Same result as #keys, iterating name and index together instead of
  # looking each index up by name.
  def keys_pairs
    keys = []
    indexes.each_pair do |name, index|
      keep = if attribute = lookup(index)
        attribute.initialized?
      else
        ActiveModel::IndexedRow.key_at?(@row, index) || attribute_at(name, index).initialized?
      end
      keys << name if keep
    end
    keys
  end

  def keys_only_row_keys = row_keys
end

built = Post.find(POST_ID).tap { _1.update!(count_0: 1) }.instance_variable_get(:@attributes)
fresh = Post.find(POST_ID).instance_variable_get(:@attributes)
raise unless built.keys == built.keys_pairs && fresh.keys == fresh.keys_pairs
puts "#{RUBY_DESCRIPTION} COLS=#{COLS}"
Benchmark.ips do |x|
  x.config(warmup: 2, time: 3)
  x.report("keys built") { built.keys }
  x.report("keys_pairs built") { built.keys_pairs }
  x.report("keys fresh") { fresh.keys }
  x.report("keys_pairs fresh") { fresh.keys_pairs }
  x.report("row_keys only") { built.keys_only_row_keys }
end
