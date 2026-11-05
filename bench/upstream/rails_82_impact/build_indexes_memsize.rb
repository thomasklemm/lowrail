require "objspace"
wt = ARGV[0]
$LOAD_PATH.unshift "#{wt}/activesupport/lib", "#{wt}/activemodel/lib"
require "active_support/core_ext/enumerable"
require "active_model/indexed_row"
puts [3, 6, 8, 12, 16].map { |n| cols = Array.new(n) { |i| -"c#{i}" }; "#{n}:#{ObjectSpace.memsize_of(ActiveModel::IndexedRow.build_indexes(cols))}" }.join(" ")
