# frozen_string_literal: true

# Differential probe for TE2: tag_options for every attribute type (none, data, aria, class,
# boolean) with Hash and other values, recording each is_a? call the value receives.
#   ruby probe.rb RAILS_DIR > out.txt
tree = ARGV.fetch(0)
%w[activesupport actionview activemodel actionpack].each { $LOAD_PATH.unshift File.join(tree, _1, "lib") }
require "action_view"
require "bigdecimal"
require "active_support/json"

view = ActionView::Base.empty
calls = []

counted = lambda do |obj|
  obj.singleton_class.prepend(Module.new do
    define_method(:is_a?) { |mod| calls << "is_a?(#{mod})"; super(mod) }
  end)
  obj
end

class HashLike
  def is_a?(mod) = mod == Hash || super
  def each_pair = yield(:x, "1")
  def to_s = "hashlike"
end

values = {
  "string" => -> { +"v<" },
  "hash" => -> { { a: 1, "b-c" => "x<", d: nil, e: [1, 2], f: { g: 1 } } },
  "empty hash" => -> { {} },
  "array" => -> { ["a", "b"] },
  "true" => -> { true },
  "false" => -> { false },
  "nil" => -> { nil },
  "symbol" => -> { :until_found },
  "hash-like object" => -> { HashLike.new },
}
keys = [:title, "title", :data, "data", :aria, "aria", :class, "class", :disabled, "disabled", :hidden, :hidden_x, "", :"", nil]

values.each do |vname, make|
  keys.each do |key|
    [true, false].each do |escape|
      calls.clear
      value = make.()
      value = counted.(value) unless value.nil? || value == true || value == false || value.is_a?(Symbol)
      calls.clear
      result = begin
        view.tag.tag_options({ key => value, id: "x" }, escape).inspect
      rescue Exception => e
        "raised #{e.class}: #{e.message}"
      end
      puts "#{key.inspect} #{vname} escape=#{escape}: #{result} calls=#{calls.join(",")}"
    end
  end
end
puts view.tag.div(data: { controller: "card" }, aria: { expanded: false, label: "x<" }, class: ["a", { b: true }], disabled: true, hidden: "until-found")
puts view.content_tag(:span, "x", { data: { a: 1 }, aria: { b: [1, nil] } })
