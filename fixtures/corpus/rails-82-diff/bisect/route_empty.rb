require "action_controller"
rs = ActionDispatch::Routing::RouteSet.new
rs.draw { resources(:posts) { resources :comments } }
rs.default_url_options = { host: "example.com" }
h = Class.new { include rs.url_helpers }.new
puts((h.post_comments_path("") rescue :raised) == :raised ? "NEW" : "OLD")
