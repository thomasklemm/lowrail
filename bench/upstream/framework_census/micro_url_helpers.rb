# frozen_string_literal: true

# Objects and ns per call of optimized named-route helpers, with and without
# route-set default_url_options, plus the generated URLs as a behavior check.
#   ruby [--yjit] -I RAILS/activesupport/lib -I RAILS/actionpack/lib micro_url_helpers.rb
require "action_dispatch"
require "action_controller"

def build(defaults)
  routes = ActionDispatch::Routing::RouteSet.new
  routes.draw do
    resources :posts do
      resources :comments
    end
    get "/about", to: "pages#about", as: :about
  end
  routes.default_url_options = defaults
  helpers = routes.url_helpers
  Class.new do
    include helpers
    define_method(:url_options) { { host: "example.com", protocol: "https", _recall: {} } }
  end.new
end

def objects(n = 1000)
  yield
  GC.disable
  before = GC.stat(:total_allocated_objects)
  n.times { yield }
  (GC.stat(:total_allocated_objects) - before).fdiv(n)
ensure
  GC.enable
end

def ns(n = 200_000)
  3.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n.times { yield }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1e9 / n
  end.min
end

puts "#{RUBY_DESCRIPTION} yjit=#{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}"
{ "no route-set defaults" => {}, "route-set defaults {host:}" => { host: "defaults.example" },
  "route-set defaults {trailing_slash:, script_name:}" => { trailing_slash: true, script_name: "/app" } }.each do |label, defaults|
  t = build(defaults)
  cases = {
    "post_path(1)" => -> { t.post_path(1) },
    "post_comment_url(1, 2)" => -> { t.post_comment_url(1, 2) },
    "post_path(1, format: :json)" => -> { t.post_path(1, format: :json) },
    "posts_path(page: 2)" => -> { t.posts_path(page: 2) },
    "about_url" => -> { t.about_url }
  }
  puts "-- #{label}"
  cases.each do |name, c|
    puts format("   %-30s %-48s %5.2f objects  %6.1f ns", name, c.().inspect, objects { c.() }, ns { c.() })
  end
end
