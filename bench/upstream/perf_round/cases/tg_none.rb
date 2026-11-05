$LOAD_PATH.unshift(*%w[activesupport actionview].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "bigdecimal"
require "action_view"
require "active_support/core_ext/object/json"
VIEW = Object.new.extend(ActionView::Helpers::TagHelper)
MICRO = {
  "tag_sym" => -> { -> { VIEW.tag.a("x", href: "/p", class: "c", data: { id: 1 }) } },
  "tag_str" => -> { -> { VIEW.content_tag(:a, "x", "href" => "/p", "class" => "c", "data" => { "id" => 1 }) } },
}
