# frozen_string_literal: true
# Prints helper outputs (or exception class+message) for many inputs; diff main vs PATCH.
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"; require "active_support/core_ext"; require "active_model"; require "action_view"
require_relative "form_stack_patches"
V = ActionView::Base.empty
rng = Random.new(42)
parts = ["post", "comment", "[", "]", "][", "_", "?", ".", ":", "-", "ä", " ", "0", "x", "[]", "a?b", "\u00e9", "\"", "<"]
names = ["", "post", "post[title]", "post[tags][]", "user_", "_", "a.b:c-d", "q?", "?", "ä", :post, :title?, nil, 12] +
        200.times.map { Array.new(rng.rand(1..5)) { parts.sample(random: rng) }.join }
names << "bad\xFF".dup.force_encoding("UTF-8") << "x".encode("UTF-16LE")
opts = [{}, { id: nil }, { "id" => nil }, { id: "x" }, { "id" => "a", id: "b" }, { class: "c", type: "email" },
        { "type" => "number", type: :range }, { value: "v" }, { name: "n" }, { autocomplete: "on" }, { data: { a: 1 } }]
def show(&b) = (b.call.inspect rescue "#{$!.class}: #{$!.message}")
names.each do |n|
  [nil, 1, "ns"].each do |idx|
    puts show { V.field_id(n, n, index: idx) }, show { V.field_id(n, :m?, "s", namespace: idx) }
    puts show { V.field_name(n, "m", index: idx) }, show { V.field_name(n, "m", "x", "y", multiple: true, index: idx) }
  end
  opts.each do |o|
    puts show { V.text_field_tag(n, "v", o.dup) }, show { V.hidden_field_tag(n, "v", o.dup) },
         show { V.email_field_tag(n, nil, o.dup) }, show { V.check_box_tag(n, "1", false, o.dup) }
  end
  puts show { V.label_tag(n) }, show { V.send(:sanitize_to_id, n) }
end
