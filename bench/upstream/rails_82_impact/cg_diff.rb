# frozen_string_literal: true

# Diff of sampled Callgrind windows (cg_profile.rb JSON) between two trees,
# per Ruby method (file + qualified name; lines shift between trees), and of
# plain Callgrind dumps per C function (callgrind_annotate, self or inclusive).
#   ruby cg_diff.rb methods OLD.json[,OLD2.json] NEW.json[,NEW2.json] [--by self|incl] [--limit N] [--grep RE]
#   ruby cg_diff.rb files   OLD.json[,..] NEW.json[,..] [--limit N]  (self by file)
#   ruby cg_diff.rb lines   OLD.json[,..] NEW.json[,..] [--limit N] [--grep RE]
#   ruby cg_diff.rb cfuncs  OLD.callgrind[,..] NEW.callgrind[,..] UNITS [--inclusive] [--limit N]
# Comma-separated files are averaged (an A/A pair); the A/A column is the
# difference inside the pair, per row, when both sides have two files.
require "json"
require "optparse"

opts = { by: "self", limit: 40 }
cmd = ARGV.shift
OptionParser.new do |o|
  o.on("--by K") { opts[:by] = _1 }
  o.on("--limit N", Integer) { opts[:limit] = _1 }
  o.on("--grep RE") { opts[:grep] = Regexp.new(_1) }
  o.on("--inclusive") { opts[:inclusive] = true }
end.parse!

def mean(hashes) = Hash.new(0).merge(hashes.flat_map(&:keys).uniq.to_h { |k| [k, hashes.sum { _1[k] } / hashes.size.to_f] })

# Compiled templates' anonymous classes differ between processes.
def anon(name) = name.gsub(/#<Class:0x\h+>/, "#<Class>").gsub(/_\d+_\d+\z/, "")

def per_unit(path, kind, by)
  j = JSON.parse(File.read(path))
  h = Hash.new(0) # sampled values are already per unit (iteration or round)
  case kind
  when "methods" then j["methods"].each { |m| h["#{m["file"]} #{anon(m["method"])}"] += m[by] }
  when "lines" then j["lines"].each { |m| h["#{m["file"]}:#{m["line"]} #{anon(m["method"])}"] += m["self"] }
  # Self cost by file partitions the window (C functions count toward the Ruby file that called them).
  when "files" then j["methods"].each { |m| h[m["file"].sub(%r{\AAPP/[^/]+/}, "APP/")] += m["self"] }
  end
  h["TOTAL (exact)"] = j.fetch("ir_per_unit") { j["ir_per_itr"] }
  h
end

def cfuncs(path, units, inclusive)
  out = IO.popen(["callgrind_annotate", "--threshold=100", *("--inclusive=yes" if inclusive), path], &:read)
  h = Hash.new(0)
  out.each_line do |line|
    next unless (m = line.match(/\A\s*([\d,]+)(?: \([ \d.]+%\))?\s+(\S.*?)\s*\z/))
    name = m[2]
    next if name.include?("PROGRAM TOTALS") || name.start_with?("Ir ")
    name = name.start_with?("???:0x") ? "<JIT code>" : name.sub(/ \[.*\]\z/, "").sub(%r{\A[^:]*:}, "").sub(/'\d+\z/, "")
    h[name] += m[1].delete(",").to_i / units.to_f
  end
  h["TOTAL"] = out[/([\d,]+)(?: \([ \d.]+%\))?\s+PROGRAM TOTALS/, 1].delete(",").to_i / units.to_f
  h
end

old_s, new_s = ARGV.shift(2).map { _1.split(",") }
load_one = case cmd
  when "methods", "lines", "files" then ->(p) { per_unit(p, cmd, opts[:by]) }
  when "cfuncs" then (units = Float(ARGV.shift)) && ->(p) { cfuncs(p, units, opts[:inclusive]) }
  else abort "usage: cg_diff.rb methods|lines|cfuncs ..."
end
olds, news = old_s.map(&load_one), new_s.map(&load_one)
a, b = mean(olds), mean(news)
aa = ->(k) { [olds, news].select { _1.size == 2 }.map { |x, y| (y[k] - x[k]).abs }.max }
keys = (a.keys | b.keys)
keys = keys.select { _1.match?(opts[:grep]) || _1.start_with?("TOTAL") } if opts[:grep]
total = keys.find { _1.start_with?("TOTAL") }
printf("%-150s %14s %14s %13s %11s\n", "key", "old", "new", "new - old", "A/A max")
rows = keys.sort_by { -(b[_1] - a[_1]).abs }
rows = [total, *(rows - [total])] if total
rows.first(opts[:limit] + 1).each do |k|
  printf("%-150s %14.0f %14.0f %+13.0f %11s\n", k.sub("RAILS/", "")[0, 150], a[k], b[k], b[k] - a[k], (v = aa.(k)) ? format("%.0f", v) : "")
end
