# frozen_string_literal: true

# Cross-app ranking of scaffold frames from analyze.rb JSON outputs.
#   ruby rank.rb [--mode interp|yjit] [--by self|total|bucket] [--top N] A.json B.json ...
# Shares are of each app's request samples. Ranked by apps reached
# (share >= 0.05%), then by mean share over all apps.
require "json"

mode = "interp"
by = "self"
top = 40
files = []
args = ARGV.dup
while (a = args.shift)
  case a
  when "--mode" then mode = args.shift
  when "--by" then by = args.shift
  when "--top" then top = Integer(args.shift)
  else files << a
  end
end

runs = files.flat_map { |f| JSON.parse(File.read(f)).to_a }
runs.select! { |label, _| mode == "yjit" ? label.end_with?("yjit") : !label.end_with?("yjit") }
apps = runs.map { |label, _| label.sub(/-(interp|interpreter|yjit)\z/, "") }
shares = Hash.new { |h, k| h[k] = {} }
runs.each do |label, r|
  app = label.sub(/-(interp|interpreter|yjit)\z/, "")
  req = r["req"].to_f
  rows = case by
  when "bucket" then r["buckets"].map { |b, n| [b, n] }
  when "total" then r["total"].select { |_, l, _| %w[actionpack rack rack-session activesupport railties].include?(l) }.map { |m, l, n| ["#{m} (#{l})", n] }
  else r["self"].map { |m, l, n| ["#{m} (#{l})", n] }
  end
  rows.each { |k, n| shares[k][app] = 100.0 * n / req }
end

puts "#{by}, #{mode}: share of request samples per app (#{apps.join(", ")})"
puts format("%-70s %5s %6s  %s", "frame", "apps", "mean", apps.map { _1[0, 9].rjust(9) }.join(" "))
shares.map { |k, per| [k, per.count { |_, v| v >= 0.05 }, apps.sum { per[_1] || 0 } / apps.size, per] }
  .sort_by { |_, reach, mean, _| [-reach, -mean] }.first(top).each do |k, reach, mean, per|
    puts format("%-70s %5d %5.2f%%  %s", k[0, 70], reach, mean, apps.map { |a| format("%8.2f%%", per[a] || 0) }.join(" "))
  end
