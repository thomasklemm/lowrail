# frozen_string_literal: true
# What an app could observe of each candidate beyond the output for plain inputs: overrides of helpers the candidate
# stops (or starts) calling, and changed error messages. Diff main against PATCH=<candidate>.
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_model"
require "action_view"
require_relative "sweep_patches"

class Post
  include ActiveModel::Model
  attr_accessor :title
end
SEEN = Hash.new(0)
def show(label)
  out = begin
    yield.inspect
  rescue Exception => e # rubocop:disable Lint/RescueException
    "#{e.class}: #{e.message}"
  end
  puts "#{label}\t#{out}\t#{SEEN.sort.inspect}"
  SEEN.clear
end

# A view whose app helpers override safe_join and tag, the way a helper module can.
view_class = Class.new(ActionView::Base.with_empty_template_cache) do
  def safe_join(array, sep = $,) = (SEEN[:view_safe_join] += 1; super)
  def tag(*args, **kw, &block) = (SEEN[:view_tag] += 1; super)
end
V = view_class.empty
F = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "t"), V, {})
show("view safe_join, tag.div class: Array") { V.tag.div("x", class: ["a", "b"]) }
show("view safe_join, f.text_field class: Array") { F.text_field(:title, class: ["a", "b"]) }
show("view tag, f.select") { F.select(:title, %w[a b], include_blank: true) }

ActionView::Helpers::TagHelper::TagBuilder.prepend(Module.new do
  def tag_options(options, escape = true) = (SEEN[:tag_options] += 1; super)
end)
show("TagBuilder#tag_options override, tag(:input)") { V.tag(:input, class: "c") }
show("TagBuilder#tag_options override, tag.br") { V.tag.br(class: "c") }
show("TagBuilder#tag_options override, content_tag") { V.content_tag(:p, "x", class: "c") }

class String
  alias_method :__dasherize, :dasherize
  def dasherize = (SEEN[:dasherize] += 1; __dasherize)
end
show("String#dasherize override, data: {controller:}") { V.tag.div(data: { controller: "c", turbo_frame: "f" }) }

class MergeCounting < Hash
  def merge(*) = (SEEN[:merge] += 1; super)
  def dup = (SEEN[:dup] += 1; super)
end
show("Hash subclass merge, hidden_field_tag") { V.hidden_field_tag("q", "v", MergeCounting[:class, "c"]) }

text_area = ActionView::Helpers::Tags::TextArea.new(:post, :title, V, {})
show("Tags content_tag, 1 argument") { text_area.send(:content_tag, "p") }
show("Tags content_tag, 5 arguments") { text_area.send(:content_tag, "p", "x", {}, true, 1) }
show("Placeholderable#initialize parameters") { ActionView::Helpers::Tags::TextField.instance_method(:initialize).parameters }
