require "active_support/all"
require "action_view"
require "benchmark/ips"

view = ActionView::Base.empty
one = { "key" => "value" }
twenty = (1..20).to_h { |i| ["key#{i}", "value#{i}"] }

Benchmark.ips do |x|
  x.report("button_to, 1 param") { view.button_to("Save", "/posts", params: one) }
  x.report("button_to, 20 params") { view.button_to("Save", "/posts", params: twenty) }
end
