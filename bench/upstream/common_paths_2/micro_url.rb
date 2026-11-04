# ruby micro_url.rb CASE N MODE   (MODE: ir | ns | obj); run from a Rails worktree (RAILS=$PWD)
require "bundler/setup"
RAILS = ENV.fetch("RAILS")
%w[activesupport actionpack actionview activemodel].each { |c| $LOAD_PATH.unshift File.join(RAILS, c, "lib") }
require "action_controller"
require "action_view"
CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
ROUTES = ActionDispatch::Routing::RouteSet.new
ROUTES.draw { resources(:posts) { resources :comments }; get "/pages/:slug", to: "pages#show", as: :page }
class Ctx
  include ROUTES.url_helpers
  def default_url_options = { host: "example.com" }
end
P = Struct.new(:id) { def to_param = id.to_s }
POST = P.new(123)
C = Ctx.new
ENC = ActionDispatch::Journey::Router::Utils
CASES = {
  "escape_segment_id" => -> { ENC.escape_segment("123") },
  "escape_segment_slug" => -> { ENC.escape_segment("my-first-post-about-rails") },
  "escape_segment_space" => -> { ENC.escape_segment("hello world") },
  "post_path" => -> { C.post_path(POST) },
  "post_comment_path" => -> { C.post_comment_path(POST, 7) },
  "page_path_slug" => -> { C.page_path("my-first-post-about-rails") },
}
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
else
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  N.times { f.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
