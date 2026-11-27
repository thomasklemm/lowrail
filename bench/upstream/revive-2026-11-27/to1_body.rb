require "action_view"

view = ActionView::Base.empty

{
  "text_field_tag" => -> { view.text_field_tag(:query, "rails") },
  "hidden_field_tag" => -> { view.hidden_field_tag(:token, "abc") },
  "submit_tag" => -> { view.submit_tag("Save") },
  "tag.input" => -> { view.tag.input(type: "text", name: "q") },
}.each do |name, helper|
  helper.call
  before = GC.stat(:total_allocated_objects)
  1000.times { helper.call }
  puts "#{name}: #{(GC.stat(:total_allocated_objects) - before) / 1000} objects"
end
