# frozen_string_literal: true
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"; require "active_support/core_ext"; require "action_view"
require_relative "form_stack_patches"
V = ActionView::Base.empty
C = {
  "hidden_field_tag(id: nil)" => -> { V.hidden_field_tag("post[tags][]", "value", id: nil) },
  "hidden_field_tag" => -> { V.hidden_field_tag("post[tag_ids][]", "1") },
  "text_field_tag" => -> { V.text_field_tag("q", "x") },
  "tag(:input) short" => -> { V.tag(:input, type: "hidden", name: "a", value: "b") },
  "button_to 20 params" => -> { V.button_to("Save", "/posts", params: (1..20).to_h { ["key#{_1}", "value#{_1}"] }) },
}
C.each do |l, f|
  3.times { f.call }; GC.disable; b = GC.stat(:total_allocated_objects); 100.times { f.call }
  printf "%-26s %6.1f\n", l, (GC.stat(:total_allocated_objects) - b) / 100.0; GC.enable
end
puts C.transform_values(&:call).values.map(&:to_s).join("\n") if ENV["OUT"]
