require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "rails", path: "."
  gem "benchmark-ips"
end

require "action_view"

view = ActionView::Base.empty

Benchmark.ips do |x|
  x.report("tag.a") { view.tag.a("Jane Doe", href: "/users/42", class: "author-link", title: "Jane Doe") }
  x.report("content_tag") { view.content_tag(:span, "Jane & John", class: "byline") }
end
