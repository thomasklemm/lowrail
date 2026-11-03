# frozen_string_literal: true

# How ZJIT dispatches C method calls (docs/upstream/zjit-cfunc-paths.md).
#   ruby SCRIPT [--top N] [--methods A,B] NAME=STATS.json[,CALLS.json] ...
# STATS.json comes from ruby_bench_jit_stats.rb (per_itr) or census/harness.rb
# stats (per_op) on a build with the stats-only dispatch counters
# (thomasklemm/ruby zjit-cfunc-dispatch-stats): inlined_cfuncs_ (inlined into
# HIR), leaf_cfuncs_ (frameless CCall), not_inlined_cfuncs_ (CCallWithFrame or
# CCallVariadic) and fallback_cfuncs_ "M (reason)" (a dynamic send that reached
# the C method). CALLS.json (ruby_bench_cfunc_calls.rb, interpreter) gives every
# call of the method; "other" is the remainder: calls from the interpreter
# (code not compiled yet, after side exits) and from C.
# Prints the methods with the most frame + fallback calls, then --methods rows.
require "json"

top = 20
methods = []
args = ARGV.dup
while (flag = args.first)&.start_with?("--")
  args.shift
  case flag
  when "--top" then top = Integer(args.shift)
  when "--methods" then methods = args.shift.split(",")
  else abort "unknown flag #{flag}"
  end
end

def per(path)
  return nil unless path
  d = JSON.parse(File.read(path))
  d["per_itr"] || d["per_op"]
end

def dispatch(stats)
  rows = Hash.new { |h, k| h[k] = { inlined: 0.0, leaf: 0.0, frame: 0.0, fallback: 0.0, reasons: Hash.new(0.0) } }
  stats.each do |key, v|
    case key
    when /\Ainlined_cfuncs_(.+)\z/ then rows[$1][:inlined] += v
    when /\Aleaf_cfuncs_(.+)\z/ then rows[$1][:leaf] += v
    when /\Anot_inlined_cfuncs_(.+)\z/ then rows[$1][:frame] += v
    when /\Afallback_cfuncs_(.+) \((.+)\)\z/
      rows[$1][:fallback] += v
      rows[$1][:reasons][$2] += v
    end
  end
  rows
end

fmt = ->(v) { v.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
args.each do |arg|
  name, files = arg.split("=", 2)
  stats_path, calls_path = files.split(",")
  rows = dispatch(per(stats_path))
  calls = per(calls_path) || {}
  puts "\n## #{name}\n\n"
  puts "| Method | calls (interp) | inlined | leaf CCall | CCallWithFrame | fallback | other | fallback reasons |"
  puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
  ranked = rows.sort_by { |_, r| -(r[:frame] + r[:fallback]) }.first(top).map(&:first)
  (ranked + (methods - ranked)).each_with_index do |m, i|
    puts "| | | | | | | | |" if i == ranked.size && methods.any? { !ranked.include?(_1) }
    r = rows[m]
    total = calls[m]
    jit = r[:inlined] + r[:leaf] + r[:frame] + r[:fallback]
    other = total ? fmt.(total - jit) : ""
    reasons = r[:reasons].sort_by { -_2 }.map { |k, v| "#{k} #{fmt.(v)}" }.join("; ")
    puts "| `#{m}` | #{total ? fmt.(total) : ""} | #{fmt.(r[:inlined])} | #{fmt.(r[:leaf])} | #{fmt.(r[:frame])} | #{fmt.(r[:fallback])} | #{other} | #{reasons} |"
  end
end
