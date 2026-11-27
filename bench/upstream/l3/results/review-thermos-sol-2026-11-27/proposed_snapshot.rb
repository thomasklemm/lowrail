require "bundler/setup"
require "active_record"

class ActiveModel::LazyIndexedAttributeSet
  def values_before_type_cast
    materialize
    attrs = @attributes&.dup
    hash = {}
    indexes.each_key do |name|
      if attribute = attrs&.[](index_for_name(name))
        hash[name] = attribute.value_before_type_cast
      end
    end
    hash
  end
end
