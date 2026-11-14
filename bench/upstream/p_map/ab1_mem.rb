# frozen_string_literal: false

# AB1 review: memory the branch's verdict map holds at its bound (1,000 user agents for :modern).
#   BUNDLE_GEMFILE=<branch Gemfile> ruby -I bench/upstream/p_map THIS
require "action_controller"
require "objspace"
require "useragent"
require "ab1_uas"

Blocker = ActionController::AllowBrowser::BrowserBlocker
limit = Blocker::VERDICTS_LIMIT

def held(limit)
  uas = Array.new(limit) { |i| yield(i) }
  requests = uas.map { |ua| ActionDispatch::Request.new("HTTP_USER_AGENT" => ua) }
  ActiveSupport::Ractors[:action_controller_allow_browser_verdicts]&.clear
  Blocker.blocked?(requests.first, versions: :modern)
  GC.start
  before = ObjectSpace.memsize_of_all
  objects_before = ObjectSpace.count_objects[:TOTAL] - ObjectSpace.count_objects[:FREE]
  requests.each { |r| Blocker.blocked?(r, versions: :modern) }
  map = ActiveSupport::Ractors[:action_controller_allow_browser_verdicts][:modern]
  raise "size #{map.size}" unless map.size == limit
  GC.start
  [ObjectSpace.memsize_of_all - before,
   ObjectSpace.count_objects[:TOTAL] - ObjectSpace.count_objects[:FREE] - objects_before,
   uas.sum(&:bytesize) / uas.size]
end

puts RUBY_DESCRIPTION
{
  "long tail (in-app, crawlers, scripts)" => ->(i) { AB1UAs.tail(20_000 + i) },
  "512-byte user agents" => ->(i) { "Mozilla/5.0 (X11; Linux x86_64) Chrome/142.0.#{i}.0 " + "x" * (512 - 52 - i.to_s.size) },
}.each do |name, ua|
  bytes, objects, mean = held(limit, &ua)
  puts format("%-38s %d entries, mean UA %3d bytes: %7.1f KB, %d objects", name, limit, mean, bytes / 1024.0, objects)
end
