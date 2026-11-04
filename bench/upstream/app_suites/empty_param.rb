require "action_controller"
require "active_model"

Rec = Struct.new(:to_param)

routes = ActionDispatch::Routing::RouteSet.new
routes.draw do
  get "/s/:id/(:title)" => "stories#show", as: "story_short_id"
  get "/p/:id" => "posts#show", as: "post"
end
klass = Class.new { include routes.url_helpers }
klass.default_url_options = { host: ENV["HOST"] } if ENV["HOST"]
h = klass.new

[
  ["story_short_id_path(Rec.new(''))", -> { h.story_short_id_path(Rec.new("")) }],
  ["story_short_id_path(id: Rec.new(''))", -> { h.story_short_id_path(id: Rec.new("")) }],
  ["story_short_id_path('')", -> { h.story_short_id_path("") }],
  ["post_path(Rec.new(''))", -> { h.post_path(Rec.new("")) }],
  ["post_path(id: '')", -> { h.post_path(id: "") }],
  ["post_path('')", -> { h.post_path("") }],
].each do |label, l|
  r = begin; l.call.inspect; rescue => e; "#{e.class}: #{e.message[0,80]}"; end
  puts "#{label.ljust(38)} #{r}"
end
