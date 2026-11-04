# frozen_string_literal: true

# Per census workload: calls of ActionView::Helpers::ControllerHelper#respond_to?
# by method name, after warmup. Run like safebuffer_count.rb:
#   bundle exec ruby respond_to_count.rb APP OUT.json
require_relative "../census/harness"

app, output = ARGV
raise "fresh output required" if File.exist?(output)
RailsCensus.boot(app)
ops = RailsCensus.workloads(app)
warmup = Integer(ENV.fetch("CENSUS_WARMUP", "50"))
count = Integer(ENV.fetch("CENSUS_REQUESTS", "10"))
target = ActionView::Helpers::ControllerHelper.instance_method(:respond_to?)

results = ops.map do |op|
  run = -> { op.call.call; RailsCensus.reset_side_effects }
  warmup.times { run.call }
  names = Hash.new(0)
  tp = TracePoint.new(:call) do |t|
    name = t.binding.local_variable_get(:method_name)
    names[name.inspect] += 1
  end
  tp.enable(target:) { count.times { run.call } }
  { workload: op.name, per_op: names.transform_values { _1.fdiv(count) }.sort_by { -_2 }.to_h }
end
File.write(output, JSON.pretty_generate(app:, ruby: RUBY_DESCRIPTION, rails: RailsCensus.rails_sha, workloads: results) + "\n")
totals = Hash.new(0)
results.each { |r| r[:per_op].each { |k, v| totals[k] += v } }
puts "#{app}: respond_to? per op over #{results.size} workloads: " + totals.sort_by { -_2 }.first(8).map { "#{_1} #{(_2 / results.size).round(1)}" }.join(", ")
