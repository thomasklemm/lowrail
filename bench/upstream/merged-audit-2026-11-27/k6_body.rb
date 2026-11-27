# frozen_string_literal: true

# K6 amendment check: text_field_tag (the line Rafael moved into a local) and
# button_to with params, which calls it once per param.
require "active_support"
require "active_support/core_ext"
require "action_view"
require "action_controller"

ROUTES = ActionDispatch::Routing::RouteSet.new
ROUTES.draw { resources(:posts) }
class View < ActionView::Base
  include ROUTES.url_helpers
end
VIEW = View.empty
VIEW.output_buffer = ActionView::OutputBuffer.new
PARAMS = (1..5).to_h { ["k#{_1}", "v#{_1}"] }.freeze

UpstreamBench.report("text_field_tag") { VIEW.text_field_tag("post[title]", "Hello") }
UpstreamBench.report("text_field_tag id:") { VIEW.text_field_tag("post[title]", "Hello", id: "t") }
UpstreamBench.report("button_to 5 params") { VIEW.button_to("Go", "/posts", params: PARAMS) }
