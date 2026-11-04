# frozen_string_literal: true

# Per census workload: append_tag_option calls by the class of the attribute
# value (which case branch they take), after warmup. Run like safebuffer_count.rb:
#   bundle exec ruby tag_value_count.rb APP OUT.json
require_relative "../census/harness"

app, output = ARGV
raise "fresh output required" if File.exist?(output)
RailsCensus.boot(app)
ops = RailsCensus.workloads(app)
warmup = Integer(ENV.fetch("CENSUS_WARMUP", "50"))
count = Integer(ENV.fetch("CENSUS_REQUESTS", "10"))
builder = ActionView::Helpers::TagHelper::TagBuilder

results = ops.map do |op|
  run = -> { op.call.call; RailsCensus.reset_side_effects }
  warmup.times { run.call }
  classes = Hash.new(0)
  tp = TracePoint.new(:call) do |t|
    v = t.binding.local_variable_get(:value)
    k = case v
        when String then "String"
        when Array, Hash then "Array/Hash"
        when Regexp then "Regexp"
        when Symbol then "Symbol"
        else v.class.name
        end
    classes[k] += 1
  end
  tp.enable(target: builder.instance_method(:append_tag_option)) { count.times { run.call } }
  { workload: op.name, per_op: classes.transform_values { _1.fdiv(count) } }
end
File.write(output, JSON.pretty_generate(app:, ruby: RUBY_DESCRIPTION, rails: RailsCensus.rails_sha, workloads: results) + "\n")
totals = Hash.new(0)
results.each { |r| r[:per_op].each { |k, v| totals[k] += v } }
puts "#{app}: per op over #{results.size} workloads: " + totals.sort_by { -_2 }.map { "#{_1} #{(_2 / results.size).round(1)}" }.join(", ")
