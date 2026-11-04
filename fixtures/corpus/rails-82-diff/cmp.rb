# usage: ruby cmp.rb A.tsv B.tsv [--errors]
a = File.foreach(ARGV[0]).to_h { |l| k, v = l.chomp.split("\t", 2); [k, v] }
b = File.foreach(ARGV[1]).to_h { |l| k, v = l.chomp.split("\t", 2); [k, v] }
fn = ->(k) { k.split("/")[0, 2].join("/") }
if ARGV[2] == "--errors"
  tot = Hash.new(0); err = Hash.new(0); msg = {}
  b.each { |k, v| f = fn.(k); tot[f] += 1; (err[f] += 1; msg[f] ||= v[0, 160]) if v.start_with?("!") }
  tot.sort.each { |f, n| puts format("%-28s %6d/%-6d %s", f, err[f], n, msg[f]) if err[f] > 0 }
  exit
end
diffs = Hash.new { |h, k| h[k] = [] }
(a.keys | b.keys).each { |k| diffs[fn.(k)] << k if a[k] != b[k] }
diffs.sort_by { -_2.size }.each do |f, ks|
  puts "== #{f}: #{ks.size} differ"
  ks.first(Integer(ENV.fetch("SHOW", "3"))).each { |k| puts "  #{k}\n    8.1:  #{a[k].to_s[0, 400]}\n    main: #{b[k].to_s[0, 400]}" }
end
