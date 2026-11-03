# frozen_string_literal: true

# Calls per operation of the given methods on census page workloads, after
# warmup, in a census copy (TracePoint :call and :c_call):
#   CENSUS_MODE=interpreter bundle exec ruby census_counts.rb APP 'meth,Klass#meth,...'
# A bare name counts calls from any owner. Klass#meth counts only methods
# defined in Klass (aliases report the original name: OutputBuffer#append= is
# ActionView::OutputBuffer#<<).
require_relative "../census/harness"

name, spec = ARGV
RailsCensus.boot(name)
ops = RailsCensus.workloads(name).select { %i[html turbo].include?(_1.kind) }
targets = spec.split(",").map do |s|
  owner, meth = s.include?("#") ? s.split("#", 2) : [nil, s]
  [s, owner && Object.const_get(owner), meth.to_sym]
end
5.times { ops.each { _1.call.call } }
RailsCensus.reset_side_effects
ops.each do |op|
  counts = Hash.new(0)
  tp = TracePoint.new(:call, :c_call) do |t|
    targets.each do |label, owner, meth|
      counts[label] += 1 if t.method_id == meth && (owner.nil? || t.defined_class == owner)
    end
  end
  tp.enable { 3.times { op.call.call } }
  puts format("%-40s %s", op.name, targets.map { |label, *| "#{label}=#{(counts[label] / 3.0).round(1)}" }.join(" "))
end
RailsCensus.reset_side_effects
