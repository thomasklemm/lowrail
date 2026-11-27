# frozen_string_literal: true

# Objects per call for each case and for the dirty-tracking pieces in isolation.
require_relative "setup_model"

def objs(n = 200)
  GC.disable
  before = GC.stat(:total_allocated_objects)
  n.times { yield }
  ((GC.stat(:total_allocated_objects) - before) / n.to_f).round(2)
ensure
  GC.enable
end

cases = l6_cases
cases.each { |name, c| 20.times { c.call }; puts "#{name}: #{objs { c.call }}" }
post = Post.find(POST_ID)
set = post.instance_variable_get(:@attributes)
puts "set class: #{set.class}"
puts "keys (loaded, untouched): #{objs { set.keys }}"
fresh = -> { Post.find(POST_ID) }
f = objs { fresh.call }
puts "find alone: #{f}"
puts "find + changed?: #{objs { fresh.call.changed? }} (changed? alone ~ #{(objs { fresh.call.changed? } - f).round(2)})"
puts "find + attribute_names: #{(objs { fresh.call.attribute_names } - f).round(2)}"
puts "find + changed_attribute_names_to_save: #{(objs { fresh.call.send(:changed_attribute_names_to_save) } - f).round(2)}"
p2 = Post.find(POST_ID); p2.count_0 += 1
puts "assigned: changed_attribute_names_to_save #{objs { p2.send(:changed_attribute_names_to_save) }}, has_changes_to_save? #{objs { p2.has_changes_to_save? }}"
