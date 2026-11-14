# frozen_string_literal: true

# Where a hot method is called from: running worker samples whose stack has a
# frame labelled LABEL (regexp), grouped by the first DEPTH frames above it
# outside the matching file. Share of server time, mean over workloads.
#   ruby callers.rb LABEL [--depth N] [--skip FILE_REGEXP] RECEIPT.json...
require_relative "report"

depth = (i = ARGV.index("--depth")) ? Integer(ARGV.slice!(i, 2)[1]) : 3
skip = (i = ARGV.index("--skip")) ? Regexp.new(ARGV.slice!(i, 2)[1]) : nil
label = Regexp.new(ARGV.shift)
totals = Hash.new(0.0)
n = 0
ARGV.each do |path|
  d = PMapReport.load(path)
  by, = PMapReport.attribute(d)
  interval_ms = d["interval_us"] / 1000.0
  per = Hash.new { |h, k| h[k] = Hash.new(0.0) }
  d["threads"].each do |t|
    next unless t["name"].match?(/tp \d+\z/)
    t["samples"].each do |stack, category, window, cnt|
      next if window.nil? || category != 0
      frames = d["stacks"].fetch(stack.to_s)
      at = frames.rindex { _1[0].match?(label) } or next
      above = frames[(at + 1)..].reject { |l, f, _| f == "<cfunc>" || f.start_with?("<internal:") || (skip && f.match?(skip)) }
      key = above.first(depth).map { |l, f, ln| "#{l} (#{PMapLayers.short(f)}:#{ln})" }.join(" < ")
      per[window]["#{d["app"]}: #{key}"] += cnt * interval_ms
    end
  end
  d["windows"].each_index do |w|
    total = by[w].values.sum
    n += 1
    per[w].each { |k, ms| totals[k] += 100.0 * ms / total }
  end
end
totals.sort_by { -_2 }.first(25).each { |k, v| puts format("%6.2f  %s", v / n, k) }
