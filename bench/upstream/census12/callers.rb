# frozen_string_literal: true

# Who calls a hot method: from a CENSUS_CPU_STACKS dump (cpu_harness), the
# sampled self instructions of frames whose label matches PATTERN, grouped by
# the nearest calling Ruby line outside that method.
#   ruby callers.rb STACKS.json PATTERN [DEPTH] [--ops N]
# DEPTH (default 1) groups by that many caller lines. Ir per op uses the
# window's work Ir over its signals, as cpu_harness does (--ops: requests in
# the window, default 10).
require "json"

path, pattern, depth = ARGV
depth = Integer(depth || 1)
ops = (i = ARGV.index("--ops")) ? Integer(ARGV[i + 1]) : 10
data = JSON.parse(File.read(path))
frames, stacks, window = data.values_at("frames", "stacks", "window")
weight = window["work_ir"].fdiv(window["signals"].nonzero? || 1) / ops
re = Regexp.new(pattern)
short = ->(f) { f.to_s.sub(%r{\A.*/(gems/[^/]+|[a-z_]+/lib)/}, '\1/') }
groups = Hash.new(0)
total = 0
stacks.each do |stack, n|
  ruby = stack.index { |id, _| frames[id][0] != "<cfunc>" } or next
  next unless re.match?(frames[stack[ruby][0]][1].to_s)
  total += n
  key = stack.drop(ruby + 1).reject { |id, _| frames[id][0] == "<cfunc>" || re.match?(frames[id][1].to_s) }
    .first(depth).map { |id, line| "#{short.(frames[id][0])}:#{line} #{frames[id][1]}" }
  groups[key.join(" <- ")] += n
end
printf("%s: %.0f Ir/op self in matching frames (%.2f%% of the window's work)\n", pattern, total * weight, 100.0 * total / window["signals"])
groups.sort_by { -_2 }.first(25).each { printf("%9.0f %5.1f%%  %s\n", _2 * weight, 100.0 * _2 / total, _1) }
