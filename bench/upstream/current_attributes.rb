# frozen_string_literal: true

# ruby [--yjit] current_attributes.rb /path/to/rails before /tmp/current
# Run again against the changed checkout with label "after" and the same prefix.
rails, label, output = ARGV
abort "usage: #{$0} RAILS_CHECKOUT LABEL OUTPUT_PREFIX" unless output
$LOAD_PATH.unshift File.join(rails, "activesupport/lib")
require "active_support"
require "active_support/current_attributes"
require "benchmark/ips"

puts RUBY_DESCRIPTION
puts "Rails #{ActiveSupport::VERSION::STRING}; benchmark-ips #{Benchmark::IPS::VERSION}"
puts "checkout: #{rails}; label: #{label}"

scenarios = {
  empty: {},
  unset: { user: ActiveSupport::CurrentAttributes::NOT_SET, account: ActiveSupport::CurrentAttributes::NOT_SET, request: ActiveSupport::CurrentAttributes::NOT_SET },
  scalar: { count: 0, enabled: false, missing: nil },
  mutable: { text: "hello", list: [], options: {} },
  callable: { count: -> { 1 }, list: -> { [] }, options: -> { {} } },
  mixed: { user: ActiveSupport::CurrentAttributes::NOT_SET, account: ActiveSupport::CurrentAttributes::NOT_SET,
    count: 0, enabled: false, missing: nil, text: "hello", list: [], options: {}, computed: -> { [] }, another: -> { {} } }
}

scenarios.each do |name, defaults|
  klass = Class.new(ActiveSupport::CurrentAttributes)
  klass.define_singleton_method(:name) { "BenchCurrent#{name}" }
  defaults.each { |key, value| klass.attribute(key, default: value) }
  current = klass.new
  operation = -> { current.reset }
  1_000.times { operation.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  20_000.times { operation.call }
  allocated = GC.stat(:total_allocated_objects) - before
  puts "#{name}: #{format('%.3f', allocated.fdiv(20_000))} objects/reset"

  Benchmark.ips do |x|
    x.config(warmup: 1, time: 3)
    x.report(label, &operation)
    x.compare!(order: :baseline)
    x.save!("#{output}-#{name}.json")
  end
end
