# frozen_string_literal: true

# Lead 6: per-column slope of lines.rb or sites.rb counts, (count at W2 - count at W1) / (W2 - W1), for each tree:
# every key with a slope of at least 0.5 in some tree, then the per-column totals of Ruby calls (R), C calls (C)
# and Rails lines (L). ruby slope.rb DIR W1 W2 TREE...   (files DIR/TREE-wW.txt)
dir, w1, w2, *trees = ARGV
read = ->(f) { File.readlines(f).to_h { |l| c, k = l.strip.split(" ", 2); [k, c.to_f] } }
s = trees.to_h do |t|
  a = read.("#{dir}/#{t}-w#{w1}.txt")
  b = read.("#{dir}/#{t}-w#{w2}.txt")
  [t, (a.keys | b.keys).to_h { |k| [k, (b.fetch(k, 0) - a.fetch(k, 0)) / (w2.to_i - w1.to_i)] }]
end
keys = s.values.flat_map(&:keys).uniq.select { |k| trees.any? { s[_1].fetch(k, 0).abs >= 0.5 } }
puts format("%-110s %s", "per column", trees.map { format("%14s", _1[0, 14]) }.join)
%w[R C L].each do |p|
  keys.select { _1.start_with?(p) }.sort.each do |k|
    puts format("%-110s %s", k[0, 110], trees.map { format("%14.1f", s[_1].fetch(k, 0)) }.join)
  end
end
%w[R C L].each do |p|
  puts format("%-110s %s", "total #{p}", trees.map { |t| format("%14.1f", s[t].select { |k, _| k.start_with?(p) }.sum { _2 }) }.join)
end
