# frozen_string_literal: true

# Objects and ns per call of view helpers that capture a block.
#   ruby [--yjit] -I RAILS/activesupport/lib -I RAILS/actionview/lib micro_capture.rb
require "action_view"

view = ActionView::Base.empty
view.output_buffer = ActionView::OutputBuffer.new

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

cases = {
  "capture { }" => -> { view.capture { "x" } },
  "capture(arg) { |a| }" => -> { view.capture(1) { |a| a.to_s } },
  "content_for(:x) { }" => -> { view.content_for(:x) { "y" }; view.view_flow.set(:x, ActiveSupport::SafeBuffer.new) },
  "tag.div { }" => -> { view.tag.div { "x" } },
  "content_tag(:div) { }" => -> { view.content_tag(:div) { "x" } },
  "OutputBuffer#capture(1) { |a| }" => -> { view.output_buffer.capture(1) { |a| a } },
  "tag.div(\"x\") (no block, control)" => -> { view.tag.div("x") }
}
# Behavior: captured content and buffer restoration.
raise unless view.capture { "<b>" } == "&lt;b&gt;" && view.capture(2) { |a| a.to_s } == "2"
raise unless view.output_buffer.capture(1, 2) { |a, b| view.output_buffer << "#{a}#{b}" } == "12"
raise unless view.tag.div { "x" } == "<div>x</div>"
puts "#{RUBY_DESCRIPTION} yjit=#{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}"
cases.each do |name, c|
  puts format("%-34s %5.2f objects  %6.1f ns", name, objects { c.() }, ns { c.() })
end
