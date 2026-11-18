# frozen_string_literal: true
require "objspace"

class ThermosDupTrace
  FROZEN_SOURCE = "constant payload".freeze
  def copy(s) = s.dup
  def constant_copy = FROZEN_SOURCE.dup
end

probe = ThermosDupTrace.new
source = +"payload"

if ARGV.first == "memory"
  100.times { probe.copy(source) }
  [20, 231, 232, 255, 256, 257, 300, 500, 1000, 3000].each do |n|
    s = ("x" * n).freeze
    copies = Array.new(10_000) { probe.copy(s) }
    puts [n, ObjectSpace.dump(s).include?('"embedded":true'),
          ObjectSpace.memsize_of(copies.first), copies.sum { ObjectSpace.memsize_of(it) },
          copies.all? { it == s && !it.equal?(s) && !it.frozen? }].inspect
  end
  exit
end

ObjectSpace.trace_object_allocations_start if ARGV.first == "early"
100.times { probe.copy(source); probe.constant_copy }
ObjectSpace.trace_object_allocations_start unless ARGV.first == "early"
begin
  [probe.copy(source), probe.constant_copy].each do |copy|
    puts [ObjectSpace.allocation_class_path(copy), ObjectSpace.allocation_method_id(copy),
          ObjectSpace.allocation_sourceline(copy), !ObjectSpace.allocation_sourcefile(copy).nil?].inspect
  end
ensure
  ObjectSpace.trace_object_allocations_stop
end
