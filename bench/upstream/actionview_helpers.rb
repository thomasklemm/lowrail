# frozen_string_literal: true

# ruby [--yjit] actionview_helpers.rb RAILS_CHECKOUT LABEL OUTPUT_PREFIX
# Run before and after in separate processes with a fresh shared output prefix.
# The candidate only replaces nested Symbol keys' to_s with name.
# These are short helper micros, not application/request-speed measurements.
rails, label, output = ARGV
abort "usage: #{$0} RAILS_CHECKOUT LABEL OUTPUT_PREFIX" unless output
%w[activesupport activemodel actionpack actionview].each do |component|
  $LOAD_PATH.unshift File.join(rails, component, "lib")
end
require "action_controller"
require "action_view"
require "active_model"
require "active_support/json"
require "benchmark/ips"

class Post
  include ActiveModel::Model
  attr_accessor :id

  def persisted?
    true
  end
end

routes = ActionDispatch::Routing::RouteSet.new
routes.draw { resources :posts }
view_class = Class.new(ActionView::Base) do
  include routes.url_helpers
end
view = view_class.empty
post = Post.new(id: 37)
text = "Search <posts> & comments"
safe = "<strong>Search</strong>".html_safe
symbols = { data: { controller: "search", action: "click->search#open", item_id: 37 } }
strings = { "data" => { "controller" => "search", "action" => "click->search#open", "item_id" => 37 } }
aria = { aria: { label: text, described_by: ["help", "errors"] } }

scenarios = {
  scalar_tag: -> { view.content_tag(:div, text, class: "card", title: text) },
  data_symbols: -> { view.content_tag(:div, text, symbols) },
  data_strings: -> { view.content_tag(:div, text, strings) },
  aria_symbols: -> { view.content_tag(:div, safe, aria) },
  nested_link: -> { view.link_to(text, "/posts/37?a=1&b=2", symbols) },
  get_button: -> { view.button_to(text, "/posts/37", method: :get, **symbols) },
  record_url: -> { view.url_for(post) },
  string_url: -> { view.url_for("/posts/37") }
}

# Validate every fixture before any timing starts.
scenarios.each_value(&:call)
abort "unexpected URL" unless scenarios[:record_url].call == "/posts/37"

puts RUBY_DESCRIPTION
puts "Rails #{ActionView::VERSION::STRING}; benchmark-ips #{Benchmark::IPS::VERSION}"
puts "checkout: #{rails}; label: #{label}"
scenarios.each do |name, operation|
  2_000.times { operation.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  20_000.times { operation.call }
  allocated = GC.stat(:total_allocated_objects) - before
  puts "#{name}: #{format('%.3f', allocated.fdiv(20_000))} objects/op"

  Benchmark.ips do |x|
    x.config(warmup: 1, time: 3)
    x.report(label, &operation)
    x.compare!(order: :baseline)
    x.save!("#{output}-#{name}.json")
  end
end
