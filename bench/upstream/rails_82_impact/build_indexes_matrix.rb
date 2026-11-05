# usage: ruby bi.rb WORKTREE N K [time]
wt, n, k, mode = ARGV[0], Integer(ARGV[1]), Integer(ARGV[2]), ARGV[3]
$LOAD_PATH.unshift "#{wt}/activesupport/lib", "#{wt}/activemodel/lib"

require "active_support/core_ext/enumerable"
require "active_model/indexed_row"
cols = Array.new(n) { |i| -"column_#{i}" }
expect = {}; cols.each_with_index { |c, i| expect[c] = i }
r = ActiveModel::IndexedRow.build_indexes(cols)
raise "mismatch" unless r == expect && r.keys == expect.keys
2000.times { ActiveModel::IndexedRow.build_indexes(cols) }
if mode == "time"
  best = Float::INFINITY
  7.times do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    k.times { ActiveModel::IndexedRow.build_indexes(cols) }
    best = [best, (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(k)].min
  end
  a0 = GC.stat(:total_allocated_objects); ActiveModel::IndexedRow.build_indexes(cols); a1 = GC.stat(:total_allocated_objects)
  puts format("%.1f ns  %d objects", best, a1 - a0 - 0)
else
  k.times { ActiveModel::IndexedRow.build_indexes(cols) }
end
