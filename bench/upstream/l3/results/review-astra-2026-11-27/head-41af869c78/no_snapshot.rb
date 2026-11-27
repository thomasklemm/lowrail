require "bundler/setup"
require "active_record"

methods = ENV.fetch("MUTANT", "values_before_type_cast").split(",")
methods.each do |method|
  file, line = ActiveModel::LazyIndexedAttributeSet.instance_method(method).source_location
  source = File.readlines(file)[(line - 1), 11].join
  abort "unexpected source" unless source.include?("attrs = @attributes&.dup") && source.end_with?("    end\n")
  ActiveModel::LazyIndexedAttributeSet.class_eval(source.sub("attrs = @attributes&.dup", "attrs = @attributes"), file, line)
end
