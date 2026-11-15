# ips.rb's reports with Rails from the tree given as the argument on $LOAD_PATH instead of
# bundler/inline, for Rubies without the tree's gem set (ZJIT on Ruby master).
tree = ARGV.fetch(0)
%w[activesupport actionview activemodel actionpack].each { $LOAD_PATH.unshift File.join(tree, _1, "lib") }
require "benchmark/ips"
require "action_view"

view = ActionView::Base.empty

Benchmark.ips do |x|
  x.report("tag.a") { view.tag.a("Jane Doe", href: "/users/42", class: "author-link", title: "Jane Doe") }
  x.report("content_tag") { view.content_tag(:span, "Jane & John", class: "byline") }
end
