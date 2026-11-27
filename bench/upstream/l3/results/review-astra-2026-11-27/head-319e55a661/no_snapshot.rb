require "bundler/setup"
require "active_record"

file, line = ActiveModel::LazyIndexedAttributeSet.instance_method(:attributes_to_hash).source_location
source = File.readlines(file)[(line - 1), 11].join
abort "unexpected source" unless source.include?("snapshot = @attributes&.dup") && source.end_with?("      end\n")
ActiveModel::LazyIndexedAttributeSet.class_eval do
  class_eval(source.sub("snapshot = @attributes&.dup", "snapshot = @attributes"), file, line)
  private :attributes_to_hash
end
