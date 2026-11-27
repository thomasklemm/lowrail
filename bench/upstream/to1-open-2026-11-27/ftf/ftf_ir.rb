# f.text_field and neighbours, Callgrind per call: N calls inside Array#cycle (--toggle-collect=rb_ary_cycle), GC off.
#   ruby ftf_ir.rb RAILS CASE N
rails, name, n = ARGV[0], ARGV[1], Integer(ARGV[2])
%w[activesupport actionview actionpack activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support/all"; require "active_model"; require "action_view"; require "action_controller"
class Post; include ActiveModel::Model; attr_accessor :title, :body; end
v = ActionView::Base.empty
f = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello world", body: "b"), v, {})
long = "x" * 200
CASES = {
  "f.text_field" => -> { f.text_field(:title) },
  "f.text_field class+placeholder" => -> { f.text_field(:title, class: "form-control input-lg", placeholder: "Your title", autocomplete: "off") },
  "f.text_field data" => -> { f.text_field(:title, class: "input", data: { controller: "autosize", action: "input->autosize#resize", autosize_max_value: 10 }, required: true) },
  "f.text_field long value" => -> { f.text_field(:title, value: long) },
  "text_field_tag" => -> { v.text_field_tag(:query, "rails") },
  "tag.input 5 attrs" => -> { v.tag.input(type: "email", name: "user[email]", id: "user_email", class: "form-control", autocomplete: "email") },
}
c = CASES.fetch(name)
3000.times { c.call }
GC.start; GC.disable
[1].cycle(n) { c.call }
