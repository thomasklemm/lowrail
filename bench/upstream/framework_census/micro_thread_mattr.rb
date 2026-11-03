# frozen_string_literal: true

# Objects and ns per call of thread_mattr_accessor readers and writers.
#   ruby [--yjit] -I RAILS/activesupport/lib micro_thread_mattr.rb
require "active_support"
require "active_support/core_ext/module/attribute_accessors_per_thread"

class Current
  thread_mattr_accessor :request_id
  thread_mattr_accessor :renderer, default: :none
end
class SubCurrent < Current; end

def objects(n = 1000)
  yield
  GC.disable
  before = GC.stat(:total_allocated_objects)
  n.times { yield }
  (GC.stat(:total_allocated_objects) - before).fdiv(n)
ensure
  GC.enable
end

def ns(n = 2_000_000)
  3.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n.times { yield }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1e9 / n
  end.min
end

Current.request_id = "a"
SubCurrent.request_id = "b"
cases = {
  "reader" => -> { Current.request_id },
  "writer" => -> { Current.request_id = "a" },
  "reader with default" => -> { Current.renderer },
  "instance reader" => -> { Current.new.request_id },
  "subclass reader (control)" => -> { SubCurrent.request_id },
  "subclass writer (control)" => -> { SubCurrent.request_id = "b" }
}
# Behavior: values stay independent per class and per thread.
raise unless Current.request_id == "a" && SubCurrent.request_id == "b"
raise unless Thread.new { Current.request_id }.value.nil?
raise unless Current.renderer == :none && SubCurrent.renderer == :none
puts "#{RUBY_DESCRIPTION} yjit=#{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}"
cases.each do |name, c|
  puts format("%-28s %5.2f objects  %6.1f ns", name, objects { c.() }, ns { c.() })
end
