rails = ARGV[0]
%w[activesupport actionview actionpack activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"; require "active_support/core_ext"; require "action_view"
def v = Object.new.extend(ActionView::Helpers::TagHelper)
def show(l) = puts("#{l}: " + (begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message[0,80]}"; end))
show("1 frozen tag(:br)") { v.freeze.tag(:br) }
show("2 name mutated") { name = +"input"; o = Object.new; o.define_singleton_method(:to_s) { name.replace("br"); "value" }; v.tag(name, id: o) }
show("3 encoding order") { o = Object.new; o.define_singleton_method(:to_s) { raise "later attribute" }; v.tag("x-é", a: "\xff".b, b: o) }
show("4a tag.self_closing_tag_string") { v.tag.self_closing_tag_string("text", id: "a") }
show("4b tag.append_tag_options") { v.tag.append_tag_options("text", id: "a") }
