# frozen_string_literal: true

# QB1: Relation::Merger#merge calls per request, by whether the other relation
# had values and where the merge came from. Runs inside a census copy:
#   [CENSUS_SET=ce2] bench/upstream/p_map/hx CORPUS APP bundle exec ruby THIS APP
require_relative "../census/harness"
require_relative "../p_map/profile"

name = ARGV.fetch(0)
RailsCensus.boot(name)
tally = Hash.new(0)
on = false
ActiveRecord::Relation::Merger.prepend(Module.new do
  define_method(:merge) do
    if on
      kind = if values.empty? then other.null_relation? ? "blank, null" : "blank"
      elsif values.equal?(relation.values_for_merge) then "self"
      else "values"
      end
      kind += ", receiver has conditions" if kind == "blank" && !(relation.where_clause.empty? && relation.having_clause.empty?)
      site = caller_locations(1, 6).map(&:label).find { _1 !~ /merge/ }
      tally[[kind, site]] += 1
    end
    super()
  end
end)
ops = RailsCensus.workloads(name)
ops += PMap.extra_ops(name, RailsCensus, ops)
ops = ops.select { %i[html json form turbo].include?(_1.kind) }
ops.each { |op| 3.times { op.call.call; RailsCensus.reset_side_effects } }
on = true
ops.each { |op| op.call.call; RailsCensus.reset_side_effects }
on = false
n = ops.size.to_f
puts "#{name}: #{(tally.values.sum / n).round(1)} merges per request (mean over #{ops.size} workloads)"
tally.group_by { |(kind, _), _| kind }.each { |kind, rows| puts format("  %-32s %5.1f", kind, rows.sum(&:last) / n) }
tally.sort_by { -_2 }.first(8).each { |(kind, site), v| puts format("  %5.1f  %-32s from %s", v / n, kind, site) }
