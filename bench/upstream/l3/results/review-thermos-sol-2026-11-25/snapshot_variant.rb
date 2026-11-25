# frozen_string_literal: true

require "bundler/setup"
require "active_record"

class ActiveModel::LazyIndexedAttributeSet
  def values_for_database
    materialize
    attributes = @attributes&.dup
    hash = {}
    indexes.each_key do |name|
      if attribute = attributes&.[](index_for_name(name))
        hash[name] = attribute.value_for_database
      end
    end
    hash
  end
end
