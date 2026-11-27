# frozen_string_literal: true
require_relative "setup_model"
require_relative "proto" if ENV["PROTO"] == "1"
def objs(n = 200)
  GC.disable
  b = GC.stat(:total_allocated_objects)
  n.times { yield }
  ((GC.stat(:total_allocated_objects) - b) / n.to_f).round(1)
ensure
  GC.enable
end
puts "COLS=#{COLS} proto=#{ENV["PROTO"] == "1"} " + l6_cases.merge(fresh_cases).map { |k, c| 20.times { c.call }; "#{k}=#{objs { c.call }}" }.join(" ")
