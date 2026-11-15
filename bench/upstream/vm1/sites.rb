# frozen_string_literal: true

# Traced YJIT exit or fallback sites per request, from jit_stats.rb runs with
# --yjit-trace-exits[=COUNTER] --yjit-trace-exits-sample-rate=N: each sample
# stands for N+1 events. Mean over an app's workloads, then over apps.
#   ruby sites.rb [--top N] [--frames K] DIR...   (DIR = runs/trace-COUNTER, holds APP.json)
require "json"

top = ARGV.include?("--top") ? Integer(ARGV[ARGV.index("--top") + 1]) : 25
frames = ARGV.include?("--frames") ? Integer(ARGV[ARGV.index("--frames") + 1]) : 3
dirs = ARGV.each_with_index.reject { |a, i| a.start_with?("--") || (i > 0 && ARGV[i - 1].start_with?("--")) }.map(&:first)
SHORT = %r{/home/[^ ]*?/(gems|bundler/gems)/|/home/[^ ]*?/\.corpus/}

dirs.each do |dir|
  per_app = {}
  Dir["#{dir}/*.json"].sort.each do |path|
    j = JSON.parse(File.read(path))
    rate = j["argv"].to_s[/sample-rate=(\d+)/, 1].to_i + 1
    w = j["windows"]
    sites = Hash.new(0.0)
    w.each do |x|
      x["exit_sites"].each do |k, v|
        key = k.split(" <- ").first(frames + 1).join(" <- ").gsub(SHORT, "")
        sites[key] += v * rate / w.size
      end
    end
    counter = File.basename(dir).sub(/\Atrace-(ce2-)?/, "")
    total = counter == "all" ? w.sum { _1["stats"].fetch("side_exit_count", 0) } / w.size : w.sum { _1["stats"].fetch(counter, 0) } / w.size
    per_app[j["app"]] = [sites, total]
  end
  apps = per_app.keys
  puts "## #{File.basename(dir)}: per request #{apps.map { |a| "#{a} #{per_app[a][1].round}" }.join(", ")}"
  keys = per_app.values.flat_map { _1[0].keys }.uniq
  rows = keys.map { |k| [k, apps.map { per_app[_1][0].fetch(k, 0) }] }.sort_by { -_2.sum / apps.size }
  rows.first(top).each do |k, vals|
    puts format("%s  mean %.0f  %s", vals.map { "%7.0f" % _1 }.join(" "), vals.sum / apps.size, k)
  end
end
