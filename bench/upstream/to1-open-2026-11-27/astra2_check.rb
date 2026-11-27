# Astra's second pass on 18fd3c4a07: an invalid US-ASCII attribute value. ruby astra2_check.rb RAILS
rails = ARGV[0]
%w[activesupport actionview actionpack activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"; require "active_support/core_ext"; require "action_view"
v = Object.new.extend(ActionView::Helpers::TagHelper)
value = "é".dup.force_encoding("US-ASCII")
[-> { v.tag(:input, id: value) }, -> { v.tag.input(id: value) }].each do |c|
  html = c.call
  t = begin; html.encode("UTF-16LE"); "transcodes"; rescue => e; e.class.name; end
  p [html.encoding.name, html.valid_encoding?, t]
end
