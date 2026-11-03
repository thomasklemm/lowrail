def count
  yield
  GC.disable; b = GC.stat(:total_allocated_objects); 1000.times { yield }
  (GC.stat(:total_allocated_objects) - b) / 1000.0
ensure GC.enable end
s = :foo; o = Object.new
{ "s.to_s" => -> { s.to_s }, '"#{s}"' => -> { "#{s}" }, '"x#{s}y"' => -> { "x#{s}y" }, "s.name" => -> { s.name }, '"#{1}"' => -> { "#{1}" }, "nil.to_s" => -> { nil.to_s }, "1.to_s" => -> { 1.to_s }, 'Time.iso8601' => -> { require "time"; Time.iso8601("2026-11-03T10:00:00Z") } }.each { |n, f| printf("%-14s %.2f\n", n, count(&f)) }
