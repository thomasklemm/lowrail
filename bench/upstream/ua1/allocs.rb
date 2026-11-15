# Objects allocated by allow_browser's check (versions: :modern) over the UA1 user agents, by source line.
#   ruby -rbundler/setup allocs.rb
require "action_controller"
require "useragent"
require "objspace"
require_relative "uas"

Request = Struct.new(:user_agent)
Blocker = ActionController::AllowBrowser::BrowserBlocker
requests = UA1::UAS.values.map { |ua| Request.new(ua) }
requests.each { |r| Blocker.new(r, versions: :modern).blocked? }

sites = Hash.new(0)
GC.disable
ObjectSpace.trace_object_allocations do
  requests.each { |r| Blocker.new(r, versions: :modern).blocked? }
end
ObjectSpace.each_object do |o|
  file = ObjectSpace.allocation_sourcefile(o) or next
  next unless file.include?("useragent") || file.include?("ua-") || file.include?("allow_browser")
  sites["#{file[%r{(lib/.*)}, 1]}:#{ObjectSpace.allocation_sourceline(o)} #{o.class}"] += 1
end
total = sites.values.sum
puts "#{RUBY_DESCRIPTION}\nobjects per check (mean over #{requests.size} user agents): #{(total.to_f / requests.size).round(1)}"
sites.sort_by { -_2 }.first(30).each { |site, n| printf "%7.1f  %s\n", n.to_f / requests.size, site }
