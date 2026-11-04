# ruby app_req.rb CASE N MODE   (MODE: ir | ns | obj | prof | val); RAILS=<worktree>
# A minimal full-stack Rails app (default middleware, cookie session, flash, CSRF) served in-process.
ENV["RAILS_ENV"] ||= "production"
require "bundler/setup"
RAILS = ENV.fetch("RAILS")
%w[activesupport actionpack actionview activemodel railties].each { |c| $LOAD_PATH.unshift File.join(RAILS, c, "lib") }
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"

class BenchApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = true
  config.enable_reloading = false
  config.yjit = false
  config.action_controller.allow_forgery_protection = true
  config.require_master_key = false
  config.root = File.expand_path("app_root", __dir__)
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.log_level = :fatal
  config.hosts.clear
  config.action_controller.perform_caching = false
  config.consider_all_requests_local = false
  config.public_file_server.enabled = true
  config.active_support.deprecation = :silence
  routes.append do
    resources(:posts) { resources :comments }
    get "/feed", to: "posts#feed"
    root "posts#index"
  end
end

Rails.application.initialize!
class ApplicationController < ActionController::Base
  before_action :set_locale
  def set_locale; @locale = :en; end
end

class PostsController < ApplicationController
  before_action :set_post, only: :show
  def index
    render inline: "<%= link_to 'x', post_path(1) %><%= csrf_meta_tags %>"
  end
  def show
    render plain: "post #{@post}"
  end
  def feed
    render json: { id: 1, title: "x" }
  end
  def create
    redirect_to post_path(1), notice: "ok"
  end
  private
    def set_post = (@post = params[:id])
end


APP = Rails.application
def env_for(path, method: "GET", params: nil, cookie: nil)
  opts = { method: method, "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
    "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.5", "HTTPS" => "on", "HTTP_HOST" => "example.com",
    "HTTP_SEC_FETCH_SITE" => "same-origin" }
  opts["HTTP_COOKIE"] = cookie if cookie
  opts[:params] = params if params
  Rack::MockRequest.env_for("https://example.com#{path}", opts)
end
_, h, _ = APP.call(env_for("/posts"))
COOKIE = Array(h["set-cookie"]).join("; ").split(/;\s*/).first

CASES = {
  "show" => -> { e = env_for("/posts/1", cookie: COOKIE); s, h, b = APP.call(e); b.close if b.respond_to?(:close); s },
  "index" => -> { e = env_for("/posts", cookie: COOKIE); s, h, b = APP.call(e); b.close if b.respond_to?(:close); s },
  "json" => -> { e = env_for("/feed", cookie: COOKIE); s, h, b = APP.call(e); b.close if b.respond_to?(:close); s },
  "env" => -> { env_for("/posts/1", cookie: COOKIE) },
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
  d = Dir[File.join(Gem.dir, "gems", "stackprof-*")].first
  $LOAD_PATH.unshift File.join(d, "lib"); $LOAD_PATH.unshift Dir[File.join(Gem.dir, "extensions", "*", "*", "stackprof-*")].first
  require "stackprof"
  GC.enable
  r = StackProf.run(mode: :cpu, interval: Integer(ENV["IV"] || 50), raw: true) { N.times { f.() } }
  File.binwrite(ENV["PROF_OUT"], Marshal.dump(r)) if ENV["PROF_OUT"]
  StackProf::Report.new(r).print_text(false, Integer(ENV["TOP"] || 60))
when "val"
  p f.()
else
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  N.times { f.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
