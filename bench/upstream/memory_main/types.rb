# frozen_string_literal: true

# GC heap by object type and imemo type (count_objects_size, count_imemo_objects), two configurations side by side,
# mean of their plain runs:   ruby types.rb OUT APP CONFIG/TREE CONFIG/TREE [SNAPSHOT=boot]
require "json"

out, app, a, b, label = ARGV
label ||= "boot"
mean = lambda do |config|
  snaps = Dir[File.join(out, config, "#{app}-rep*.jsonl")].filter_map do |path|
    rows = File.readlines(path).map { JSON.parse(_1) }
    rows.any? { _1["done"] } ? rows.filter_map { _1["snapshot"] }.find { _1["label"] == label } : nil
  end
  sizes = snaps.map { _1["count_objects_size"].merge(_1["imemo"].transform_keys { |k| "count:#{k}" }) }
  sizes.flat_map(&:keys).uniq.to_h { |k| [k, sizes.sum { _1.fetch(k, 0) }.fdiv(sizes.size)] }.merge("runs" => snaps.size)
end
x = mean.(a)
y = mean.(b)
puts format("%-24s %14s %14s %12s", "#{app} #{label}", a, b, "Δ")
(x.keys | y.keys).sort_by { -(y.fetch(_1, 0) - x.fetch(_1, 0)).abs }.each do |k|
  puts format("%-24s %14.0f %14.0f %+12.0f", k, x.fetch(k, 0), y.fetch(k, 0), y.fetch(k, 0) - x.fetch(k, 0))
end
