# frozen_string_literal: true

# ruby actionview_helper_controls.rb RAILS_CHECKOUT SNAPSHOT.json
# Compare snapshots from clean main and the nested Symbol#name experiment.
require "json"
rails, output = ARGV
abort "usage: #{$0} RAILS_CHECKOUT SNAPSHOT.json" unless output
%w[activesupport activemodel actionpack actionview].each do |component|
  $LOAD_PATH.unshift File.join(rails, component, "lib")
end
require "action_controller"
require "action_view"
require "active_support/json"
require "bigdecimal"

class StringValue
  def to_s
    "<value> & \"quoted\""
  end
end

class SafeValue
  def to_s
    '<em>safe "value"</em>'.html_safe
  end
end

def snapshot
  result = yield
  [result.class.name, result.bytes, result.encoding.name, result.html_safe?, result.frozen?]
rescue StandardError => error
  [error.class.name, error.message]
end

view = ActionView::Base.empty
values = [nil, false, true, 37, 1.25, BigDecimal("2.75"), :symbol, "", "plain",
  "<unsafe> & \"quotes\"", '<b>safe "quotes"</b>'.html_safe, ["one", "<two>"],
  { enabled: true, disabled: false }, /a"b/, StringValue.new, SafeValue.new,
  "é漢字", "\xFF".b, "\xFF".dup.force_encoding("UTF-8")]
keys = [:item_id, "item_id", :"unsafe<key", "unsafe<key", :"é_key", 37, nil, false, "", " "]
rows = {}
values.each_with_index do |value, vi|
  keys.each_with_index do |key, ki|
    [true, false].each do |escape|
      [:data, "data", :aria, :custom_prefix].each do |prefix|
        options = { prefix => { key => value } }
        id = "#{vi}/#{ki}/#{escape}/#{prefix.inspect}"
        rows["content/#{id}"] = snapshot { view.content_tag(:div, value, options, escape) }
        rows["tag/#{id}"] = snapshot { view.tag(:input, options, false, escape) }
      end
    end
  end
end

# Helper subclass dispatch and safe_join remain live in the experiment.
builder_class = Class.new(ActionView::Helpers::TagHelper::TagBuilder) do
  private
    def append_prefix_tag_option(output, prefix, key, value, escape)
      super(output, prefix, key, "override:#{value}", escape)
    end
end
custom_view = ActionView::Base.empty
custom_view.instance_variable_set(:@tag_builder, builder_class.new(custom_view))
rows["builder_override"] = snapshot { custom_view.content_tag(:div, "x", data: { item_id: 37 }) }
def custom_view.safe_join(array, separator = nil)
  super(array, separator).safe_concat(" [joined]")
end
rows["safe_join_override"] = snapshot { custom_view.content_tag(:div, "x", aria: { labelled_by: ["one", "two"] }) }

# Removing a seemingly redundant quote pass is not valid for SafeBuffer.
rows["safe_attribute_quotes"] = snapshot { view.tag.input(value: '"'.html_safe) }

# A supported dasherize implementation must already accept frozen Strings.
rows["frozen_string_key"] = snapshot { view.tag.div(data: { "item_id" => 37 }) }
string_subclass = Class.new(String) do
  def to_s
    self
  end
end
rows["string_subclass_key"] = snapshot { view.tag.div(data: { string_subclass.new("item_id") => 37 }) }

# Preserve live non-mutating overrides at both inflection boundaries.
String.prepend(Module.new do
  def dasherize
    "string-#{super}"
  end
end)
ActiveSupport::Inflector.singleton_class.prepend(Module.new do
  def dasherize(word)
    "inflector-#{super}"
  end
end)
rows["string_and_inflector_overrides_symbol"] = snapshot { view.tag.div(data: { item_id: 37 }) }
rows["string_and_inflector_overrides_frozen_string"] = snapshot { view.tag.div(data: { "item_id" => 37 }) }

# url_target must retain name.respond_to? before inspecting the options Hash.
options = {}
name = Object.new
name.define_singleton_method(:respond_to?) do |method, *args|
  options[:remote] = true if method == :model_name
  false
end
name.define_singleton_method(:to_s) { "name" }
def view.url_for(options)
  options.inspect
end
rows["url_target_evaluation_order"] = snapshot { view.link_to(name, options) }
rows["remote_mutation"] = options

File.write(output, JSON.pretty_generate(rows) + "\n")
puts "#{rows.size} stock/helper-override snapshots written to #{output}"

# Incompatible extension control: the live String#dasherize extension
# receives a fresh mutable String on main, but a shared frozen String after.
# This intentionally in-place override also fails frozen String keys on main
# and violates dasherize's existing non-mutating, frozen-input contract.
String.prepend(Module.new do
  define_method(:dasherize) do
    tr!("_", "-")
    self
  end
end)
puts "in-place override, Symbol: #{snapshot { view.content_tag(:div, 'x', data: { item_id: 37 }) }.inspect}"
puts "in-place override, frozen String: #{snapshot { view.content_tag(:div, 'x', data: { 'item_id' => 37 }) }.inspect}"
