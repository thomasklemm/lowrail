# frozen_string_literal: true

# Whole-request micro for the 8-1-stable vs main round: a one-file Rails app
# (production defaults, full middleware stack, cookie session, CSRF) for a
# Rails checkout given in RAILS. Same modes as micro.rb:
#   RAILS=DIR ruby [--yjit] app_micro.rb CASE N ir|stats|ns
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord actionview actionpack railties].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
ENV["RAILS_ENV"] = "production"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "rack/mock"

class MicroApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = true
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.log_level = :info
  config.hosts.clear
  config.active_support.deprecation = :silence
  config.consider_all_requests_local = false
  config.action_dispatch.show_exceptions = :none
  config.action_controller.perform_caching = false
  config.root = __dir__
  config.paths["app/views"] = []
end

MicroApp.initialize!
MicroApp.routes.draw do
  get "/posts/:id" => "posts#show", as: :post
  get "/posts/:id/json" => "posts#json"
  get "/form" => "posts#form"
  post "/posts" => "posts#create"
end
class PostsController < ActionController::Base
  def show
    session[:n] = (session[:n] || 0) + 1
    render plain: "post #{params[:id]}"
  end

  def json
    render json: { id: params[:id].to_i, title: "t", tags: %w[a b] }
  end

  def form
    render inline: "<%= form_with url: '/posts', method: :post do |f| %><%= f.text_field :title %><% end %><%= link_to 'x', post_path(1) %>"
  end

  skip_forgery_protection only: :create

  def create
    head :no_content
  end
end

Rails.logger.level = :fatal
ActiveSupport.event_reporter.debug_mode = false if ActiveSupport.respond_to?(:event_reporter)

APP = MicroApp
raise "Rails not loaded from #{rails}" unless Rails.method(:application).source_location.first.start_with?(File.expand_path(rails) + "/")

def env_for(path, method: "GET", cookie: nil, params: nil)
  Rack::MockRequest.env_for(path, method:, "HTTP_HOST" => "example.org", "HTTP_ACCEPT" => "text/html",
    "HTTP_COOKIE" => cookie, params:).compact
end

def call!(env)
  status, headers, body = APP.call(env)
  body.each { |_| } if body.respond_to?(:each)
  body.close if body.respond_to?(:close)
  raise "HTTP #{status} for #{env["PATH_INFO"]}" unless status < 400
  headers
end

COOKIE = call!(env_for("/posts/1"))["set-cookie"].to_s.split(";").first

CASES = {
  "get_plain" => -> { call!(env_for("/posts/1")) },
  "get_session" => -> { call!(env_for("/posts/1", cookie: COOKIE)) },
  "get_json" => -> { call!(env_for("/posts/1/json")) },
  "get_form" => -> { call!(env_for("/form", cookie: COOKIE)) },
  "post_create" => -> { call!(env_for("/posts", method: "POST", params: { title: "x" })) },
}

if ARGV[0] == "list"
  puts CASES.keys
  exit
end

name, n, mode = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
fn = CASES.fetch(name)
500.times { fn.() }
GC.start
GC.disable
case mode
when "ir"
  [nil].cycle(n) { fn.() }
when "stats"
  before = GC.stat(:total_allocated_objects)
  1000.times { fn.() }
  puts "#{name} #{(GC.stat(:total_allocated_objects) - before) / 1000.0} objects"
when "ns"
  GC.enable
  20_000.times { fn.() }
  GC.start
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  n.times { fn.() }
  puts format("%.1f", (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(n))
end
