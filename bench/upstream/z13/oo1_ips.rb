require "benchmark/ips"
require "active_support/ordered_options"
base = ActiveSupport::OrderedOptions.new
base.asset_host = "x"
leaf = ActiveSupport::InheritableOptions.new(ActiveSupport::InheritableOptions.new(base))
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)
  x.report(ENV["LABEL"]) { leaf[:asset_host] }
end
