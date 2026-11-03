# frozen_string_literal: true

# Aggregates script/framework-probe work outputs across apps, breadth first
# like the allocation ranking: a key reaches a workload at >= 0.5 calls per
# operation; keys are tiered by apps reached (>= 7, 5-6, 3-4, 2, 1), then by
# mean calls per operation over every workload.
#   ruby probe_rank.rb PROBE_DIR MODE SECTION [LIMIT] [FILTER_REGEXP]
# SECTION: calls | method_missing | c_calls.
require "json"

dir, mode, section, limit, filter = ARGV
mode ||= "interpreter"
filter = Regexp.new(filter) if filter
runs = Dir["#{dir}/*-#{mode}.json"].sort.map { JSON.parse(File.read(_1)) }
workloads = runs.flat_map { |run| run["workloads"].map { [run["app"].sub(/-mysql\z/, ""), _1] } }
total = workloads.size
per = Hash.new { |h, k| h[k] = [] }
workloads.each do |app, w|
  w.fetch(section).each { |key, n| per[key] << [app, n] if !filter || key.match?(filter) }
end
tiers = [7, 5, 3, 2]
rows = per.map do |key, hits|
  reach = hits.select { _2 >= 0.5 }
  { key: key, apps: reach.map(&:first).uniq.size, share: reach.size.fdiv(total), mean: hits.sum(&:last) / total }
end
rows.sort_by! { |r| [tiers.index { r[:apps] >= _1 } || tiers.size, -r[:mean]] }
puts "#{runs.size} runs, #{total} workloads (#{mode}), #{section}#{" =~ #{filter.source}" if filter}"
rows.first(Integer(limit || 40)).each_with_index do |r, i|
  puts format("%3d apps %d share %4.0f%% mean %8.2f  %s", i + 1, r[:apps], r[:share] * 100, r[:mean], r[:key][0, 160])
end
