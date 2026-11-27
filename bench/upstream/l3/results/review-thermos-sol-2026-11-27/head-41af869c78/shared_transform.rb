require "bundler/setup"
require "active_record"

class ActiveModel::LazyIndexedAttributeSet
  def values_before_type_cast
    attributes_to_hash { |attribute| attribute.value_before_type_cast }
  end

  def values_for_database
    attributes_to_hash { |attribute| attribute.value_for_database }
  end

  private
    def attributes_to_hash
      materialize
      snapshot = @attributes&.dup
      hash = {}
      indexes.each_key do |name|
        if attribute = snapshot&.[](index_for_name(name))
          hash[name] = yield(attribute)
        end
      end
      hash
    end
end
