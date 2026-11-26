# frozen_string_literal: true

# Objects per request by source line, for each workload of app.rb.
#   ruby -Ilib-of-tree alloc_lines.rb [FILTER] [N]   (run with BUNDLE_GEMFILE pointing at a Gemfile with the tree)
# FILTER is a substring of the file path (default inertia); `all` lists every line.
require_relative "app"
require "objspace"

filter = ARGV[0] || "inertia"
n = Integer(ARGV[1] || 200)
InertiaBench::WORKLOADS.each_key do |name|
  200.times { InertiaBench.call(name) }
  GC.start
  GC.disable
  counts = Hash.new(0)
  total = 0
  ObjectSpace.trace_object_allocations do
    before = GC.stat(:total_allocated_objects)
    n.times { InertiaBench.call(name) }
    total = GC.stat(:total_allocated_objects) - before
    ObjectSpace.each_object do |o|
      file = ObjectSpace.allocation_sourcefile(o) or next
      next unless filter == "all" || file.include?(filter)
      next if file == __FILE__

      counts["#{file.sub(%r{.*/(lib|app)/}, '\1/')}:#{ObjectSpace.allocation_sourceline(o)} #{o.class}"] += 1
    rescue StandardError
      next
    end
  end
  GC.enable
  mine = counts.values.sum
  puts "== #{name}: #{(total.fdiv(n)).round(1)} objects/request, #{mine.fdiv(n).round(1)} on #{filter} lines"
  counts.sort_by { -_2 }.first(Integer(ENV.fetch("TOP", "25"))).each { |k, v| puts format("%8.2f  %s", v.fdiv(n), k) }
end
