# frozen_string_literal: true

# AB1 review: what a miss adds on the branch, in one process (the branch's uncached check is main's code),
# and main's check for the user agent the request profile sent.
#   BUNDLE_GEMFILE=<branch Gemfile> taskset -c 1 ruby --yjit -I bench/upstream/p_map THIS
require "action_controller"
require "useragent"
require "benchmark/ips"
require "ab1_uas"

Blocker = ActionController::AllowBrowser::BrowserBlocker
unique = AB1UAs.mixes["unique"].map { |ua| ActionDispatch::Request.new("HTTP_USER_AGENT" => ua) }
census = ActionDispatch::Request.new("HTTP_USER_AGENT" => AB1UAs::TOP20[12])
puts RUBY_DESCRIPTION

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)
  i = j = 0
  n = unique.size
  x.report("miss, uncached check") { Blocker.new(unique[i], versions: :modern).blocked?; i += 1; i = 0 if i == n }
  x.report("miss, cached check") { Blocker.blocked?(unique[j], versions: :modern); j += 1; j = 0 if j == n }
  x.report("Firefox 140 Linux, uncached") { Blocker.new(census, versions: :modern).blocked? }
  x.report("Firefox 140 Linux, parse only") { UserAgent.parse(census.user_agent) }
  x.compare!
end

GC.disable
[[:uncached, ->(r) { Blocker.new(r, versions: :modern).blocked? }], [:cached, ->(r) { Blocker.blocked?(r, versions: :modern) }]].each do |name, check|
  check.(unique.first)
  before = GC.stat(:total_allocated_objects)
  unique.each { |r| check.(r) }
  puts format("%-8s %.2f objects per miss", name, (GC.stat(:total_allocated_objects) - before).fdiv(unique.size))
end
