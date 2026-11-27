# frozen_string_literal: true

# Call versus body for LazyIndexedAttributeSet's helpers: each variant loops over
# the 30 names (or their indexes) of a loaded, fully built record; per-element ns
# minus the empty loop is the cost of the step.
require "benchmark/ips"
require_relative "setup_model"

class ActiveModel::LazyIndexedAttributeSet
  def t_empty(names) = names.each { |n| n }
  def t_index_for_name(names) = names.each { |n| index_for_name(n) }
  def t_indexes_reader(names) = names.each { |n| indexes[n] }
  def t_ivar_hash(names) = names.each { |n| @indexes[n] }
  def t_ivar_only(names) = names.each { |n| @indexes }
  def t_lookup(idx) = idx.each { |i| lookup(i) }
  def t_lookup_inline(idx) = idx.each { |i| @attributes&.[](i) }
  def t_attribute_at(pairs) = pairs.each { |n, i| attribute_at(n, i) }
  def t_attribute_at_inline(pairs) = pairs.each { |n, i| @attributes&.[](i) || default_attribute(n, i) }
  def t_row_keys = row_keys
  def t_keys = keys
end

post = Post.find(POST_ID)
post.update!(count_0: 1) # builds every attribute
set = post.instance_variable_get(:@attributes)
names = set.send(:row_keys)
idx = names.map { set.indexes[_1] }
pairs = names.zip(idx)
x = Benchmark.ips(quiet: true) do |b|
  b.config(warmup: 2, time: 2)
  b.report("empty") { set.t_empty(names) }
  b.report("index_for_name") { set.t_index_for_name(names) }
  b.report("indexes[name]") { set.t_indexes_reader(names) }
  b.report("@indexes[name]") { set.t_ivar_hash(names) }
  b.report("@indexes") { set.t_ivar_only(names) }
  b.report("lookup") { set.t_lookup(idx) }
  b.report("@attributes&.[]") { set.t_lookup_inline(idx) }
  b.report("attribute_at") { set.t_attribute_at(pairs) }
  b.report("attribute_at inline") { set.t_attribute_at_inline(pairs) }
  b.report("row_keys (per #keys)") { set.t_row_keys }
  b.report("keys (per #keys)") { set.t_keys }
end
per = x.entries.to_h { [_1.label, 1e9 / _1.stats.central_tendency] }
empty = per["empty"]
puts "#{RUBY_DESCRIPTION}, #{names.size} names"
per.each do |label, ns|
  if label.include?("per #keys")
    puts format("  %-24s %8.1f ns per call", label, ns)
  else
    puts format("  %-24s %6.2f ns per element (loop %.1f ns subtracted)", label, (ns - empty) / names.size, empty / names.size)
  end
end
