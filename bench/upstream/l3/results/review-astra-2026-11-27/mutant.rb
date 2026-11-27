require "bundler/setup"
require "active_record"

source = File.read(File.join(ENV.fetch("RAILS"), "activemodel/lib/active_model/attribute_set.rb"))
method = source[/    def values_for_database\n      materialize.*?^    end/m]
abort "snapshot method not found" unless method&.include?("attrs = @attributes&.dup")
ActiveModel::LazyIndexedAttributeSet.class_eval(method.sub("attrs = @attributes&.dup", "attrs = @attributes"), __FILE__, 8)
