# frozen_string_literal: true

# ruby [--yjit] notifications.rb /path/to/rails before /tmp/notifications
# Run again against the changed checkout with label "after" and the same prefix.
rails, label, output = ARGV
abort "usage: #{$0} RAILS_CHECKOUT LABEL OUTPUT_PREFIX" unless output
$LOAD_PATH.unshift File.join(rails, "activesupport/lib")
require "active_support"
require "active_support/notifications"
require "benchmark/ips"

puts RUBY_DESCRIPTION
puts "Rails #{ActiveSupport::VERSION::STRING}; benchmark-ips #{Benchmark::IPS::VERSION}"
puts "checkout: #{rails}; label: #{label}"

class SilenceableSubscriber
  def start(*)
  end

  def finish(*)
  end

  def silenced?(name)
    true
  end
end

%i[empty silenced timed monotonic event_object mixed].each do |name|
  fanout = ActiveSupport::Notifications::Fanout.new
  fanout.subscribe("bench", SilenceableSubscriber.new) if [:silenced, :mixed].include?(name)
  fanout.subscribe("bench") { |*args| } if [:timed, :mixed].include?(name)
  fanout.subscribe("bench", monotonic: true) { |*args| } if name == :monotonic
  fanout.subscribe("bench") { |event| } if name == :event_object
  payload = {}
  operation = -> do
    handle = fanout.build_handle("bench", "id", payload)
    handle.start
    handle.finish
  end
  1_000.times { operation.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  20_000.times { operation.call }
  allocated = GC.stat(:total_allocated_objects) - before
  puts "#{name}: #{format('%.3f', allocated.fdiv(20_000))} objects/cycle"

  Benchmark.ips do |x|
    x.config(warmup: 1, time: 3)
    x.report(label, &operation)
    x.compare!(order: :baseline)
    x.save!("#{output}-#{name}.json")
  end
end
