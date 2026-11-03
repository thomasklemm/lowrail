# frozen_string_literal: true

# Objects and ns per event delivered to an ActiveSupport::Subscriber
# (LogSubscriber and StructuredEventSubscriber dispatch through it).
#   ruby [--yjit] -I RAILS/activesupport/lib micro_subscriber.rb
require "active_support"
require "active_support/subscriber"

class BenchSubscriber < ActiveSupport::Subscriber
  attr_reader :last, :name, :count
  def initialize = (super; @count = 0)
  def render_template(event) = (@last = :render_template; @name = event.name; @count += 1)
  def sql(event) = (@last = :sql; @name = event.name; @count += 1)
end
BenchSubscriber.attach_to :bench

# Control: the same subscriber instance subscribed by hand to a Regexp, which
# goes through the name-slicing path.
manual = BenchSubscriber.new
ActiveSupport::Notifications.subscribe(/\.manual\z/, manual)

def objects(n = 1000)
  yield
  GC.disable
  before = GC.stat(:total_allocated_objects)
  n.times { yield }
  (GC.stat(:total_allocated_objects) - before).fdiv(n)
ensure
  GC.enable
end

def ns(n = 300_000)
  3.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n.times { yield }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1e9 / n
  end.min
end

sub = ActiveSupport::Subscriber.subscribers.grep(BenchSubscriber).first
event = ActiveSupport::Notifications::Event.new("render_template.bench", nil, nil, "id", {})
manual_event = ActiveSupport::Notifications::Event.new("sql.manual", nil, nil, "id", {})
cases = {
  "Subscriber#call (attached)" => -> { sub.call(event) },
  "instrument render_template.bench" => -> { ActiveSupport::Notifications.instrument("render_template.bench") { } },
  "Subscriber#call (manual Regexp, control)" => -> { manual.call(manual_event) }
}
# Behavior: dispatch reaches the method named by the event; detaching stops it.
sub.call(event)
raise unless [sub.last, sub.name] == [:render_template, "render_template.bench"]
manual.call(manual_event)
raise unless [manual.last, manual.name] == [:sql, "sql.manual"]
puts "#{RUBY_DESCRIPTION} yjit=#{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}"
cases.each do |name, c|
  puts format("%-42s %5.2f objects  %6.1f ns", name, objects { c.() }, ns { c.() })
end
BenchSubscriber.detach_from :bench
before = sub.count
ActiveSupport::Notifications.instrument("render_template.bench") { }
raise "still subscribed" unless sub.count == before
