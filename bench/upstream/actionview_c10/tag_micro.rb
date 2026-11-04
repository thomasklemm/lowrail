# frozen_string_literal: true

# Tag helper and other Action View helper calls, per call:
#   BUNDLE_GEMFILE=VARIANT/Gemfile ruby [--yjit|--zjit] tag_micro.rb CASE N MODE
# MODE: ir (N calls inside Array#cycle, for Callgrind's --toggle-collect=rb_ary_cycle),
# ns (wall ns per call), obj (objects per call), out (print the result once).
require "bundler/setup"
require "action_view"

CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
view = ActionView::Base.empty

CASES = {
  "div_str" => -> { view.tag.div("x", class: "card", id: "card_1") },
  "link" => -> { view.content_tag(:a, "Post", href: "/posts/1", class: "btn btn-primary") },
  "input" => -> { view.tag.input(type: "text", name: "q", value: "rails") },
  "div_arr" => -> { view.tag.div("x", class: ["card", "card--active"]) },
  "div_data" => -> { view.tag.div("x", data: { controller: "toggle", action: "click->toggle#flip" }) },
  "div_sym" => -> { view.tag.div("x", dir: :ltr) },
  "div_int" => -> { view.tag.div("x", tabindex: 0) },
  "div_block" => -> { view.tag.div(class: "card") { "x" } },
  "stylesheet" => -> { view.stylesheet_link_tag("/application.css") },
  "rt_config" => -> { view.respond_to?(:config) },
  "rt_request" => -> { view.respond_to?(:request) },
  "rt_response" => -> { view.respond_to?(:response) },
  "asset_path" => -> { view.asset_path("application.css") },
}.freeze

f = CASES.fetch(CASE)
Integer(ENV.fetch("WARMUP", "3000")).times { f.() }
GC.start
GC.disable
case MODE
when "ir"
  [0].cycle(1) { N.times { f.() } }
when "obj"
  b = GC.stat(:total_allocated_objects)
  N.times { f.() }
  puts (GC.stat(:total_allocated_objects) - b).fdiv(N)
when "out"
  puts f.()
else
  GC.enable
  best = Float::INFINITY
  Integer(ENV.fetch("ROUNDS", "7")).times do
    GC.start
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    N.times { f.() }
    best = [best, (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N)].min
  end
  puts best.round(1)
end
