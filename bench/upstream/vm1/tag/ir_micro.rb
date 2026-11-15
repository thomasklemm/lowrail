# Callgrind instructions per iteration of ips.rb's two reports for the Rails tree given as the
# argument: warm up, GC off, then N iterations inside Array#cycle, which ir_micro.sh toggles on.
#   valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle ruby [--yjit|--zjit] ir_micro.rb TREE N
tree, n = ARGV
%w[activesupport actionview activemodel actionpack].each { $LOAD_PATH.unshift File.join(tree, _1, "lib") }
require "action_view"

view = ActionView::Base.empty
op = lambda do
  view.tag.a("Jane Doe", href: "/users/42", class: "author-link", title: "Jane Doe")
  view.content_tag(:span, "Jane & John", class: "byline")
end
3000.times { op.call }
GC.start
GC.disable
[op].cycle(Integer(n)) { |o| o.call }
