# frozen_string_literal: true

# Compare index_with_heap.rb runs: ruby SCRIPT DIR RUBY BASE VARIANT...
# DIR holds APP-RUBY-MODE-VARIANT.json. Per app and mode, summed over all
# workloads (per operation): GC-enabled objects (median of 3 x 20 ops) and slot
# bytes, the GC-disabled window's malloc bytes, Hash spills (<= 8 entries), and
# index_with's arrays and spilled hashes; each as VARIANT - BASE.
require "json"

dir, ruby, base, *variants = ARGV
median = ->(a) { a.sort[a.size / 2] }
load = ->(f) { JSON.parse(File.read(f))["workloads"].to_h { [_1["workload"], _1] } }
sum = ->(ws, &blk) { ws.values.sum { blk.(_1) } }
metrics = {
  objects: ->(w) { median.(w["gc_enabled_objects_per_op"]) },
  slot_bytes: ->(w) { median.(w["gc_enabled_slot_bytes_per_op"]) },
  malloc_bytes: ->(w) { w["window_per_op"]["malloc_bytes"] },
  spills_le8: ->(w) { w["spills_per_op"].fetch("hashes_le8_spilled", 0) },
  iw_arrays: ->(w) { w["enumerable_rb_per_op"].fetch("arrays", 0) },
  iw_hashes: ->(w) { w["enumerable_rb_per_op"].fetch("hashes", 0) },
  iw_spilled: ->(w) { w["enumerable_rb_per_op"].fetch("hashes_le8_spilled", 0) },
}
variants.each do |v|
  puts "\n#{ruby}: #{v} - #{base} (sums over workloads, per op)"
  puts "| app | mode | workloads | hit | objects | slot B | malloc B | ≤8 spills | index_with Arrays | index_with Hashes | index_with ≤8 spilled |"
  puts "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
  Dir[File.join(dir, "*-#{ruby}-*-#{base}.json")].sort.each do |bf|
    vf = bf.sub(/-#{base}\.json\z/, "-#{v}.json")
    next unless File.exist?(vf)
    app, mode = File.basename(bf).match(/\A(.+)-#{ruby}-(interpreter|yjit)-/).captures
    b, a = load.(bf), load.(vf)
    hit = b.count { |_, w| w["enumerable_rb_per_op"].fetch("hashes", 0) > 0 }
    row = metrics.map do |k, f|
      d = sum.(a, &f) - sum.(b, &f)
      k == :iw_arrays || k == :iw_hashes || k == :iw_spilled ? "#{sum.(b, &f).round(1)}→#{sum.(a, &f).round(1)}" : format("%+.1f", d)
    end
    puts "| #{app} | #{mode} | #{b.size} | #{hit} | #{row.join(" | ")} |"
  end
end
