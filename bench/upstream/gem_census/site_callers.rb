# frozen_string_literal: true

# Who executes a gem line during an app's census workloads (after warmup): the
# first caller frame outside the line's own gem, grouped, so harness work
# (rack-test, Rack::MockRequest/MockResponse) is told apart from app work.
# Run like the census harness, inside a census copy with its variant bundle:
#   SITES="rack/lib/rack/response.rb:61,i18n/lib/i18n/backend/fallbacks.rb:60" \
#     bundle exec ruby site_callers.rb APP
require_relative "../census/harness"

name = ARGV.fetch(0)
RailsCensus.boot(name)
ops = RailsCensus.workloads(name)
ops.each { |op| 3.times { op.call.call; RailsCensus.reset_side_effects } }
GEM = %r{/gems/([^/]+?)-(?:\d[^/]*|\h{12})/(.+)\z}
wanted = ENV.fetch("SITES").split(",").to_h do |spec|
  path, line = spec.split(/:(?=\d+\z)/)
  [[path[%r{\A[^/]+}], path.sub(%r{\A[^/]+/}, ""), Integer(line)], spec]
end
short = lambda do |loc|
  path = loc.absolute_path || loc.path.to_s
  if (m = path.match(GEM)) then "#{m[1]}/#{m[2]}:#{loc.lineno}"
  elsif path.start_with?(Rails.root.to_s) then "APP/#{path.delete_prefix(Rails.root.to_s + "/")}:#{loc.lineno}"
  elsif path.include?("/rails-") then path.sub(%r{.*/rails-\h{12}/}, "RAILS/") + ":#{loc.lineno}"
  else path.sub(%r{.*/bench/}, "LOWRAIL/bench/") + ":#{loc.lineno}"
  end
end
counts = Hash.new { |h, k| h[k] = Hash.new(0) }
tp = TracePoint.new(:line) do |t|
  m = t.path.match(GEM) or next
  spec = wanted[[m[1], m[2], t.lineno]] or next
  frames = caller_locations(1, 40)
  outside = frames.map(&short).find { !_1.start_with?("#{m[1]}/") }
  harness = outside.nil? || outside.start_with?("rack-test/", "rack/lib/rack/mock", "LOWRAIL/")
  counts[spec][[harness ? "harness" : "app", outside].join(" ")] += 1
end
ops.each do |op|
  tp.enable { op.call.call }
  RailsCensus.reset_side_effects
end
wanted.each_value do |spec|
  rows = counts[spec]
  app = rows.select { |k, _| k.start_with?("app") }.values.sum
  puts "== #{spec}: #{rows.values.sum} hits over #{ops.size} workloads, #{app} from app code"
  rows.sort_by { -_2 }.first(Integer(ENV.fetch("TOP", "5"))).each { |loc, n| puts format("%6d  %s", n, loc[0, 200]) }
end
