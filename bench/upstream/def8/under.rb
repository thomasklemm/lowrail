# frozen_string_literal: true

# Frames below a piece in a harness.rb profile, by inclusive share of the piece:
#   ruby under.rb PROFILE.json WORKLOAD REGEX [TOP]
require "json"

prof = JSON.parse(File.read(ARGV[0]))
wi = prof["windows"].index { _1["name"] == ARGV[1] } or abort "no workload"
re = Regexp.new(ARGV[2])
top = Integer(ARGV.fetch(3, "25"))
inclusive = Hash.new(0)
self_time = Hash.new(0)
total = 0
prof["samples"].each do |stack_idx, w, weight|
  next unless w == wi
  frames = prof["stacks"][stack_idx.to_s].reverse
  at = frames.index { re.match?(_1) } or next
  total += weight
  frames[at..].uniq.each { inclusive[_1] += weight }
  self_time[frames.last] += weight
end
all = prof["samples"].sum { |_, w, weight| w == wi ? weight : 0 }
puts "#{ARGV[2]}: #{total} samples (#{(100.0 * total / all).round(2)}% of all #{ARGV[1]} samples incl. wait)"
puts "inclusive:"
inclusive.sort_by { -_2 }.first(top).each { puts format("  %6.1f%%  %s", 100.0 * _2 / total, _1) }
puts "self:"
self_time.sort_by { -_2 }.first(top / 2).each { puts format("  %6.1f%%  %s", 100.0 * _2 / total, _1) }
