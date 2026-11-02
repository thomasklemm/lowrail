# frozen_string_literal: true

# Census 4 deltas: ruby SCRIPT ROOT BASE LABEL...
# Per app and mode: median GC-enabled objects per operation, LABEL - BASE,
# summarized as (workloads moved by <= -1.0, min delta, mean delta).
require "json"

root, base, *labels = ARGV
load_run = ->(label, file) { JSON.parse(File.read(File.join(root, label, file))) }
median = ->(a) { a.sort[a.size / 2] }
files = Dir[File.join(root, base, "*.json")].map { File.basename(_1) }.sort
labels.each do |label|
  puts "== #{label} vs #{base}"
  all = Hash.new { |h, k| h[k] = [] }
  files.each do |file|
    next unless File.exist?(File.join(root, label, file))
    b = load_run.(base, file)["workloads"].to_h { [_1["workload"], median.(_1["gc_enabled_objects_per_op"])] }
    a = load_run.(label, file)["workloads"].to_h { [_1["workload"], median.(_1["gc_enabled_objects_per_op"])] }
    deltas = b.keys.to_h { [_1, (a.fetch(_1) - b.fetch(_1)).round(1)] }
    moved = deltas.count { _2 <= -1.0 }
    mode = file[/-(interpreter|yjit)\.json\z/, 1]
    all[mode].concat(deltas.values)
    detail = deltas.map { |w, d| "#{w} #{format("%+.1f", d)}" }.join("; ")
    puts format("%-30s moved %2d/%2d median %+6.1f min %+7.1f | %s", file.delete_suffix(".json"), moved, deltas.size,
      median.(deltas.values), deltas.values.min, ENV["DETAIL"] ? detail : "")
  end
  all.each do |mode, d|
    puts format("ALL %-11s workloads %3d  median %+5.1f  moved<=-1: %3d  moved>=+1: %3d", mode, d.size, median.(d),
      d.count { _1 <= -1.0 }, d.count { _1 >= 1.0 })
  end
end
