# ruby micro_ap.rb CASE N MODE   (MODE: ir | ns | obj); RAILS=<worktree>
require "bundler/setup"
RAILS = ENV.fetch("RAILS")
%w[activesupport actionpack actionview activemodel].each { |c| $LOAD_PATH.unshift File.join(RAILS, c, "lib") }
require "action_controller"
require "action_view"
CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"

ROUTES = ActionDispatch::Routing::RouteSet.new
ROUTES.draw do
  resources(:posts) { resources :comments }
  get "/pages/:slug", to: "pages#show", as: :page
  root "posts#index"
end
ROUTES.default_url_options = { host: "example.com" } if ENV["RS_DEFAULTS"]

class PostsController < ActionController::Base
  include ROUTES.url_helpers
  def index; end
end
P = Struct.new(:id) { def to_param = id.to_s }
POST = P.new(123)

def controller
  env = Rack::MockRequest.env_for("https://example.com/posts?x=1", "HTTP_ACCEPT" => "text/html,application/xhtml+xml,*/*;q=0.8",
    "HTTP_USER_AGENT" => "Mozilla/5.0", "HTTP_COOKIE" => "a=1; b=2")
  req = ActionDispatch::Request.new(env)
  req.routes = ROUTES
  req.path_parameters = { controller: "posts", action: "index" }
  c = PostsController.new
  c.set_request!(req)
  c.set_response!(PostsController.make_response!(req))
  c
end
C = controller
C.url_options

CASES = {
  "post_path" => -> { C.post_path(POST) },
  "post_url" => -> { C.post_url(POST) },
  "posts_path" => -> { C.posts_path },
  "post_comment_path" => -> { C.post_comment_path(POST, 7) },
  "url_for_hash" => -> { C.url_for(controller: "posts", action: "show", id: 1, only_path: true) },
}
eval(File.read(ENV["EXTRA"])) if ENV["EXTRA"]
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 3000).to_i.times { f.() }
GC.start
GC.disable
case MODE
when "ir"
  [0].cycle(1) { N.times { f.() } }
when "obj"
  b = GC.stat(:total_allocated_objects)
  N.times { f.() }
  puts (GC.stat(:total_allocated_objects) - b).fdiv(N)
when "prof"
  sp = Gem::Specification.find_all_by_name("stackprof").first rescue nil
  d = Dir[File.join(Gem.dir, "gems", "stackprof-*")].first
  $LOAD_PATH.unshift File.join(d, "lib"); $LOAD_PATH.unshift Dir[File.join(Gem.dir, "extensions", "*", "*", "stackprof-*")].first
  require "stackprof"
  GC.enable
  r = StackProf.run(mode: :cpu, interval: 20) { N.times { f.() } }
  StackProf::Report.new(r).print_text(false, 40)
when "val"
  p f.()
else
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  N.times { f.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
