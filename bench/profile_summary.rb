# frozen_string_literal: true

# Summarize a raw stackprof profile by area (gem or app) and by frame.
#   ruby bench/profile_summary.rb profile.json [APP_ROOT] [TOP]
# "self" = samples where the frame is on top; "total" = samples where it is
# anywhere on the stack (counted once per sample).

require "json"

path, app_root, top = ARGV
top = Integer(top || 25)
prof = JSON.parse(File.read(path))
frames = prof.fetch("frames")
raw = prof.fetch("raw")

def area(file, app_root)
  return "erb(app)" if file.include?("/app/views/")
  return "app" if app_root && file.start_with?(app_root) && !file.include?("/vendor/")
  # Git-sourced Rails has one bundler checkout, not one gem path per component.
  return Regexp.last_match(1) if file =~ %r{/rails-[^/]+/(action[a-z]+|active[a-z]+|railties)/lib/}
  return Regexp.last_match(1) if file =~ %r{/gems/([a-z_\-]+?)-\d[^/]*/}
  return "ruby-stdlib" if file.include?("/lib/ruby/4") || file.include?("/lib/ruby/3")
  file.empty? ? "(native)" : "other"
end

stacks = []
i = 0
while i < raw.length
  len = raw[i]
  stack = raw[i + 1, len]
  count = raw[i + 1 + len]
  stacks << [stack, count]
  i += len + 2
end
total = stacks.sum { _2 }

self_by_frame = Hash.new(0)
total_by_frame = Hash.new(0)
self_by_area = Hash.new(0)
total_by_area = Hash.new(0)
# A C function has no line; charge its self time to the Ruby frame that
# called it, so "Hash#fetch" inside ActionView counts as actionview.
# Compiled ERB can have sampled lines without a method-definition line.
ruby_frame = ->(f) { f["line"].to_i > 0 || f["lines"]&.any? }
stacks.each do |stack, count|
  self_by_frame[stack.last] += count
  caller_id = stack.reverse.find { ruby_frame.(frames.fetch(_1.to_s)) }
  self_by_area[caller_id ? area(frames.fetch(caller_id.to_s)["file"].to_s, app_root) : "(native)"] += count
  stack.uniq.each { |f| total_by_frame[f] += count }
  stack.select { ruby_frame.(frames.fetch(_1.to_s)) }.map { area(frames.fetch(_1.to_s)["file"].to_s, app_root) }.uniq.each { total_by_area[_1] += count }
end

pct = ->(n) { format("%5.1f%%", 100.0 * n / total) }
puts "samples: #{total}"
puts "\nby area (self / total):"
self_by_area.keys.union(total_by_area.keys).sort_by { -self_by_area[_1] }.each do |a|
  puts format("  %-28s %s  %s", a, pct.(self_by_area[a]), pct.(total_by_area[a]))
end
label = lambda do |id|
  f = frames.fetch(id.to_s)
  ruby_frame.(f) ? "#{f["name"]} (#{area(f["file"].to_s, app_root)}:#{f["line"] || "generated"})" : "#{f["name"]} (C)"
end
puts "\ntop #{top} frames by self:"
self_by_frame.sort_by { -_2 }.first(top).each { |id, n| puts "  #{pct.(n)}  #{label.(id)}" }
puts "\ntop #{top} frames by total:"
total_by_frame.sort_by { -_2 }.first(top).each { |id, n| puts "  #{pct.(n)}  #{label.(id)}" }
