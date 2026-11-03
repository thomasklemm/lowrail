# frozen_string_literal: true

# Paired wall-time check of C1 inside one erubi-rails process (ruby-bench's
# benchmark app and render call), for a machine whose run-to-run noise hides a
# few percent. Alternates blocks of BLOCK renders with OutputBuffer#<< as on
# main and as on the C1 branch (the same method body, defined at run time, with
# its aliases rebound), ROUNDS times in ABBA order, after warming both. Prints
# the median of per-pair ratios. B=main2 gives the A/A control (main's method
# redefined under a second name). Run from benchmarks/erubi-rails, main bundle:
#   BUNDLE_GEMFILE=Gemfile.main-a ruby [--yjit] erubi_paired.rb
ENV["RAILS_ENV"] = "production"
ENV["SECRET_KEY_BASE"] ||= "1"
require "bundler/setup"
require "./config/environment"

BLOCK = Integer(ENV.fetch("BLOCK", "2000"))
ROUNDS = Integer(ENV.fetch("ROUNDS", "20"))

module Variants
  MAIN = ActionView::OutputBuffer.instance_method(:<<)
  module_function

  def use(variant)
    klass = ActionView::OutputBuffer
    if variant != :c1
      klass.define_method(:<<, MAIN)
    else
      klass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def <<(value)
          unless value.nil?
            value = value.to_s
            @raw_buffer << if value.html_safe?
              value
            else
              ERB::Escape.html_escape(value)
            end
          end
          self
        end
      RUBY
    end
    klass.alias_method :concat, :<<
    klass.alias_method :append=, :<<
  end
end

controller = FakeDiscourseController.new
render = -> { BLOCK.times { FakeDiscourseController.render :topics_show, assigns: controller.stub_assigns } }
time = ->(variant) do
  Variants.use(variant)
  render.call # rewarm after redefinition (YJIT invalidates dependent code)
  GC.start
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  render.call
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
end
# B=main2 runs the A/A control: the main method redefined, same schedule.
b = ENV.fetch("B", "c1").to_sym
2.times { time.(:main); time.(b) }
ratios = ROUNDS.times.map do |i|
  order = i.even? ? [:main, b] : [b, :main]
  t = order.to_h { [_1, time.(_1)] }
  t[b] / t[:main]
end.sort
median = ratios[ratios.size / 2]
puts format("%s yjit=%s: #{b}/main median %+.2f%%, IQR [%+.2f, %+.2f] over %d pairs of %d renders",
  RUBY_DESCRIPTION[0, 40], !!(defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?), 100 * (median - 1),
  100 * (ratios[ratios.size / 4] - 1), 100 * (ratios[3 * ratios.size / 4] - 1), ROUNDS, BLOCK)
