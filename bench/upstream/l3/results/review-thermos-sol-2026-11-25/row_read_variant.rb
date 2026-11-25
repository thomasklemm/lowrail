# frozen_string_literal: true

require "bundler/setup"
require "active_record"

class ActiveModel::LazyIndexedAttributeSet
  def values_for_database
    hash = {}
    indexes.each_key do |name|
      index = index_for_name(name)
      if attribute = lookup(index)
        hash[name] = attribute.value_for_database
      elsif ActiveModel::IndexedRow.key_at?(@row, index)
        hash[name] = type_for(index).serialize(value_at(index, name))
      elsif @ctx.type_key_at?(index)
        hash[name] = default_attribute(name, index).value_for_database
      end
    end
    hash
  end
end
