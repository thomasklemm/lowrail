# frozen_string_literal: true

require "active_record"

[0, 1, 30, 102, 32_768].each do |size|
  names = Array.new(size) { |i| "column_#{i.to_s.rjust(32, '0')}".freeze }
  indexes = names.each_with_index.to_h.freeze
  types = names.to_h { |name| [name, ActiveModel::Type::Integer.new] }
  context = ActiveModel::AttributeSet::Builder::Context.new(names.freeze,
    ActiveModel::AttributeSet::Builder::TypeTable.new(names, types), Array.new(size).freeze)
  full = ActiveModel::LazyIndexedAttributeSet.new(Array.new(size, 7).freeze, indexes, context)
  missing = ActiveModel::LazyIndexedAttributeSet.new([].freeze, indexes, context)
  UpstreamBench.report("keys #{size} full raw row") { full.keys }
  UpstreamBench.report("keys #{size} absent row") { missing.keys }
end
