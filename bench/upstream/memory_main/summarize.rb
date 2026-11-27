# frozen_string_literal: true

# Tables for README.md from a run.rb output directory:
#   ruby summarize.rb OUT > tables.md
# Plain runs only (rep1, rep2). Memory is RssAnon (anonymous resident memory,
# what a forked worker cannot share once written) and the GC heap's
# count_objects_size TOTAL, after full GCs. MB is 10^6 bytes.
require "json"

out = ARGV.fetch(0)
CONFIGS = %w[r4010-interpreter r4010-zjit master-interpreter master-zjit].freeze
TREES = %w[r81 main].freeze
APPS = %w[blog writebook pingcrm redprints-cfp react-starter-kit sure].freeze

def load(path)
  return nil unless File.exist?(path)
  rows = File.readlines(path).map { JSON.parse(_1) }
  return nil unless rows.any? { _1["done"] }
  snaps = rows.filter_map { _1["snapshot"] }.to_h { [_1["label"], _1] }
  { snaps: snaps, samples: rows.filter_map { _1["sample"] } }
end

RUNS = {}
CONFIGS.product(TREES, APPS, %w[rep1 rep2]).each do |c, t, a, r|
  RUNS[[c, t, a, r]] = load(File.join(out, c, t, "#{a}-#{r}.jsonl"))
end

METRICS = {
  "anon" => ->(s) { s["rss_kb"]["RssAnon"] * 1024.0 },
  "rss" => ->(s) { s["rss_kb"]["VmRSS"] * 1024.0 },
  "heap" => ->(s) { s["count_objects_size"]["TOTAL"].to_f },
  "imemo" => ->(s) { s["count_objects_size"]["T_IMEMO"].to_f },
  "slots" => ->(s) { s["gc"]["heap_live_slots"].to_f },
  "zjit" => ->(s) { (s["jit"] || {}).fetch("total_mem_bytes", 0).to_f },
  "zjit_code" => ->(s) { (s["jit"] || {}).fetch("code_region_bytes", 0).to_f },
  "zjit_alloc" => ->(s) { (s["jit"] || {}).fetch("zjit_alloc_bytes", 0).to_f },
  "zjit_frames" => ->(s) { (s["jit"] || {}).fetch("jit_frame_region_bytes", 0).to_f },
  "zjit_exits" => ->(s) { (s["jit"] || {}).fetch("side_exit_size_bytes", 0).to_f },
}.freeze

# [rep1, rep2] values of a metric at a snapshot, or of growth per request.
def values(c, t, a, metric, label)
  %w[rep1 rep2].map do |r|
    run = RUNS[[c, t, a, r]] or next nil
    f = METRICS.fetch(metric)
    if label == :growth
      (f.(run[:snaps]["r5000"]) - f.(run[:snaps]["r1000"])) / 4000.0
    else
      f.(run[:snaps][label])
    end
  end
end

def mean(v) = v.compact.empty? ? nil : v.compact.sum / v.compact.size
def aa(v) = v.compact.size == 2 ? (v[0] - v[1]).abs : nil
def mb(x) = x.nil? ? "–" : format("%.1f", x / 1e6)
def b(x) = x.nil? ? "–" : format("%.0f", x)
def signed(x, unit) = x.nil? ? "–" : (unit == :mb ? format("%+.1f", x / 1e6) : format("%+.0f", x))

def level_table(title, metric, label, unit: :mb)
  puts "### #{title}", ""
  puts "| app | " + CONFIGS.product(TREES).map { |c, t| "#{c} #{t}" }.join(" | ") + " |"
  puts "|---|" + "---:|" * (CONFIGS.size * TREES.size)
  APPS.each do |a|
    cells = CONFIGS.product(TREES).map do |c, t|
      v = values(c, t, a, metric, label)
      m = mean(v)
      d = aa(v)
      unit == :mb ? "#{mb(m)} ±#{mb(d)}" : "#{b(m)} ±#{b(d)}"
    end
    puts "| #{a} | #{cells.join(" | ")} |"
  end
  puts
end

# Delta of means, with the larger A/A spread of the two sides.
def delta_table(title, metric, label, unit: :mb)
  puts "### #{title}", ""
  cols = []
  CONFIGS.each { |c| cols << ["Rails main − 8.1, #{c}", [c, "main"], [c, "r81"]] }
  %w[interpreter zjit].each do |m|
    TREES.each { |t| cols << ["Ruby master − 4.0.10, #{m}, #{t}", ["master-#{m}", t], ["r4010-#{m}", t]] }
  end
  %w[r4010 master].each { |r| cols << ["ZJIT − interpreter, #{r}, main", ["#{r}-zjit", "main"], ["#{r}-interpreter", "main"]] }
  puts "| app | " + cols.map(&:first).join(" | ") + " |"
  puts "|---|" + "---:|" * cols.size
  APPS.each do |a|
    cells = cols.map do |_, (c1, t1), (c0, t0)|
      v1 = values(c1, t1, a, metric, label)
      v0 = values(c0, t0, a, metric, label)
      next "–" unless mean(v1) && mean(v0)
      noise = [aa(v1), aa(v0)].compact.max
      "#{signed(mean(v1) - mean(v0), unit)} (A/A #{unit == :mb ? mb(noise) : b(noise)})"
    end
    puts "| #{a} | #{cells.join(" | ")} |"
  end
  puts
end

puts "## Levels (mean of two runs ± their difference)", ""
level_table("RssAnon after boot and eager load, MB", "anon", "boot")
level_table("GC heap (count_objects_size TOTAL) after boot, MB", "heap", "boot")
level_table("RssAnon after 1,000 requests, MB", "anon", "r1000")
level_table("GC heap after 1,000 requests, MB", "heap", "r1000")
level_table("RssAnon growth per request, requests 1,000 to 5,000, bytes", "anon", :growth, unit: :b)
level_table("GC heap growth per request, requests 1,000 to 5,000, bytes", "heap", :growth, unit: :b)
level_table("Live objects (heap_live_slots) growth per request, requests 1,000 to 5,000", "slots", :growth, unit: :b)
level_table("ZJIT total_mem_bytes after boot, MB", "zjit", "boot")
level_table("ZJIT total_mem_bytes after 1,000 requests, MB", "zjit", "r1000")
level_table("ZJIT code_region_bytes after 1,000 requests, MB", "zjit_code", "r1000")
level_table("ZJIT zjit_alloc_bytes after 1,000 requests, MB", "zjit_alloc", "r1000")
level_table("ZJIT jit_frame_region_bytes after 1,000 requests, MB (master only)", "zjit_frames", "r1000")
level_table("ZJIT side_exit_size_bytes (inside code_region_bytes) after 1,000 requests, MB (master only)", "zjit_exits", "r1000")
level_table("ZJIT total_mem_bytes after 5,000 requests, MB", "zjit", "r5000")
puts "## Differences", ""
delta_table("RssAnon after boot, MB", "anon", "boot")
delta_table("GC heap after boot, MB", "heap", "boot")
delta_table("RssAnon after 1,000 requests, MB", "anon", "r1000")
delta_table("GC heap after 1,000 requests, MB", "heap", "r1000")
delta_table("RssAnon growth per request (1,000 to 5,000), bytes", "anon", :growth, unit: :b)
delta_table("GC heap growth per request (1,000 to 5,000), bytes", "heap", :growth, unit: :b)
