# frozen_string_literal: true

# Lead 6: per-column self Ir by C function, from callgrind_annotate of cg.sh dumps (200 calls each).
#   ruby fn_slope.rb DIR W1 W2 TREE...   slope = (Ir/call at W2 - Ir/call at W1) / (W2 - W1) per function
# INCLUSIVE=1 uses inclusive cost. LIMIT rows (default 40), ranked by the spread across trees.
dir, w1, w2, *trees = ARGV
ann = File.join(ENV.fetch("VALGRIND_PREFIX", File.expand_path("~/c8-valgrind")), "bin/callgrind_annotate")
incl = ENV["INCLUSIVE"] ? "--inclusive=yes" : "--inclusive=no"
read = lambda do |f|
  out = IO.popen([ann, incl, "--threshold=100", f], &:read)
  out.each_line.filter_map do |l|
    next unless (m = l.match(/^\s*([\d,]+)\s+\(\s*[\d.]+%\)\s+(.+?)(?:\s+\[.*\])?$/))
    [m[2].strip.sub(%r{\A.*?ruby-[\d.]+/(\./)?}, ""), m[1].delete(",").to_i / 200.0]
  end.group_by(&:first).transform_values { _1.sum(&:last) }
end
s = trees.to_h do |t|
  a = read.("#{dir}/#{t}-w#{w1}.cg")
  b = read.("#{dir}/#{t}-w#{w2}.cg")
  [t, (a.keys | b.keys).to_h { |k| [k, (b.fetch(k, 0) - a.fetch(k, 0)) / (w2.to_i - w1.to_i)] }]
end
keys = s.values.flat_map(&:keys).uniq
rows = keys.map { |k| [k, trees.map { s[_1].fetch(k, 0) }] }.sort_by { |_, v| -(v.max - v.min) }
puts format("%-58s %s", "Ir per column, by function", trees.map { format("%14s", _1[0, 14]) }.join)
rows.first(Integer(ENV.fetch("LIMIT", "40"))).each { |k, v| puts format("%-58s %s", k[0, 70], v.map { format("%14.1f", _1) }.join) }
