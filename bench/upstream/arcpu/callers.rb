# frozen_string_literal: true

# For frames matching PATTERN: inclusive samples split by direct caller and by
# direct callee (% of all samples). Usage: ruby callers.rb PATTERN DUMP...
require "stackprof"

pat = Regexp.new(ARGV.shift)
def short(f)
  return "?" unless f
  file = f[:file].to_s.sub(%r{.*/(activerecord|activemodel|activesupport|actionpack|actionview|railties)/lib/}, "").sub(%r{.*/gems/}, "GEM/")
  "#{f[:name]} (#{file}:#{f[:line]})"
end

ARGV.each do |path|
  d = Marshal.load(File.binread(path))
  frames = d[:frames]
  raw = d[:raw]
  total = 0
  incl = 0
  callers = Hash.new(0)
  callees = Hash.new(0)
  names = Hash.new { |h, a| h[a] = short(frames[a]) }
  match = Hash.new { |h, a| h[a] = names[a].match?(pat) }
  i = 0
  while i < raw.size
    len = raw[i]
    stack = raw[i + 1, len]
    w = raw[i + 1 + len]
    i += len + 2
    total += w
    idx = stack.index { |a| match[a] } # outermost match
    next unless idx
    incl += w
    callers[names[stack[idx - 1]]] += w if idx > 0
    callees[idx + 1 < stack.size ? names[stack[idx + 1]] : "(self)"] += w
  end
  puts "== #{File.basename(path)}: inclusive #{format('%.2f', 100.0 * incl / total)}%"
  puts "  callers:"
  callers.sort_by { -_2 }.first(8).each { |k, v| puts format("    %6.2f  %s", 100.0 * v / total, k) }
  puts "  callees:"
  callees.sort_by { -_2 }.first(12).each { |k, v| puts format("    %6.2f  %s", 100.0 * v / total, k) }
end
