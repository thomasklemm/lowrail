# frozen_string_literal: true

# Which callers reach a method during census 4 workloads (after warmup).
#   CALLERS="Time#change,Hash#stringify_keys" ruby SCRIPT APP
# Prints the top caller locations (two frames, Rails paths shortened) per method.
require_relative "rails_main_census_4"

name = ARGV.fetch(0)
RailsMainCensus4.boot(name)
ops = RailsMainCensus4.workloads(name)
ops.each { |op| 3.times { op.call.call; RailsMainCensus4.reset_side_effects } }
wanted = ENV.fetch("CALLERS").split(",").to_h do |spec|
  owner, meth = spec.split("#")
  [[Object.const_get(owner), meth.to_sym], spec]
end
counts = Hash.new { |h, k| h[k] = Hash.new(0) }
short = ->(loc) { loc.to_s.sub(%r{.*/rails-[0-9a-f]{12}/}, "").sub(%r{.*/gems/}, "GEM/").sub(Rails.root.to_s + "/", "APP/") }
tp = TracePoint.new(:call, :c_call) do |t|
  spec = wanted[[t.defined_class, t.method_id]]
  next unless spec
  locs = caller_locations(2, 2)
  counts[spec][locs.map(&short).join("  <-  ")] += 1
end
ops.each do |op|
  tp.enable { op.call.call }
  RailsMainCensus4.reset_side_effects
end
counts.each do |spec, rows|
  puts "== #{spec} (#{rows.values.sum} calls over #{ops.size} workloads)"
  rows.sort_by { -_2 }.first(Integer(ENV.fetch("TOP", "8"))).each { |loc, n| puts format("%6d  %s", n, loc[0, 220]) }
end
