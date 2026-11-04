require "bundler/setup"
%w[activesupport actionview actionpack].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "action_view"; require "action_view/testing/resolvers"
CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
VIEW = ActionView::Base.with_empty_template_cache.with_view_paths(ActionView::FixtureResolver.new("posts/show.html.erb" => "<p><%= @x %> <%= 1 + 1 %></p>"))
CASES = {
  "render" => -> { VIEW.render(template: "posts/show") },
  "hfe" => -> { ActionView::Template.handler_for_extension(:erb) },
}
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 3000).to_i.times { f.() }
GC.start; GC.disable
case MODE
when "ir" then [0].cycle(1) { N.times { f.() } }
when "obj" then b = GC.stat(:total_allocated_objects); N.times { f.() }; puts (GC.stat(:total_allocated_objects) - b).fdiv(N)
else t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond); N.times { f.() }; puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
