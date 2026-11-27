require "bundler/setup"
require "benchmark/ips"
module UpstreamBench
  CASES = {}
  def self.report(name, &block) = CASES[name] = block
end
load File.expand_path('../../../../../../bench/upstream/lead6/body/l6_body.rb', __dir__)
puts RUBY_DESCRIPTION
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)
  UpstreamBench::CASES.each { |name, block| x.report(name, &block) }
end
