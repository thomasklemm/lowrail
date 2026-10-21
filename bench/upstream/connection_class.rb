# frozen_string_literal: true

# Use fresh output prefixes for each experiment; run before, then after.
# ruby [--yjit] connection_class.rb /path/to/rails before /tmp/connection
rails, label, output = ARGV
abort "usage: #{$0} RAILS_CHECKOUT LABEL OUTPUT_PREFIX" unless output
%w[activesupport activemodel activerecord].each do |component|
  $LOAD_PATH.unshift File.join(rails, component, "lib")
end
require "active_record"
require "benchmark/ips"

puts RUBY_DESCRIPTION
puts "Rails #{ActiveRecord::VERSION::STRING}; benchmark-ips #{Benchmark::IPS::VERSION}"
puts "checkout: #{IO.popen(['git', '-C', rails, 'rev-parse', 'HEAD'], &:read).strip}; label: #{label}"
puts "tracked changes: #{IO.popen(['git', '-C', rails, 'diff', '--stat', 'HEAD'], &:read).strip}"
puts "YJIT: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}"

base = Class.new(ActiveRecord::Base)
base.abstract_class = true
base.connection_class = true
middle = Class.new(base)
leaf = Class.new(middle)
leaf.connection_class = false

scenarios = {
  false_flag: -> { leaf.connection_class },
  true_flag: -> { base.connection_class },
  ancestor_lookup: -> { leaf.connection_class_for_self },
  live_setter: -> do
    leaf.connection_class = true
    leaf.connection_class?
    leaf.connection_class = false
    leaf.connection_class?
  end
}

scenarios.each do |name, operation|
  10_000.times { operation.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  100_000.times { operation.call }
  allocated = GC.stat(:total_allocated_objects) - before
  puts "#{name}: #{format('%.5f', allocated.fdiv(100_000))} objects/operation"

  Benchmark.ips do |x|
    x.config(warmup: 2, time: 5)
    x.report(label, &operation)
    x.compare!(order: :baseline)
    x.save!("#{output}-#{name}.json")
  end
end
