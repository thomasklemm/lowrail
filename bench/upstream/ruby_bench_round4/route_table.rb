# Per-route table from route_dump.rb outputs: requests, stories, bytes, objects per pass.
fs = ARGV
t = fs.map { |f| File.readlines(f).map { _1.chomp.split("\t") } }
key = ->(p) { p =~ %r{^/(s|u|threads|comments)/.} ? "/#{$1}/:x#{p.end_with?("reply") ? "/reply" : ""}" : p }
agg = Hash.new { |h, k| h[k] = fs.map { [0, 0, 0, 0] } }
t.each_with_index { |rows, i| rows.each { |p, s, b, n, o| abort "non-200 #{p}" unless s == "200"; a = agg[key[p]][i]; a[0] += 1; a[1] += b.to_i; a[2] += n.to_i; a[3] += o.to_i } }
puts "| route | requests | " + fs.map { "#{File.basename(_1, ".tsv")}: stories / KB / objects" }.join(" | ") + " |"
puts "| --- | ---: |" + " ---: |" * fs.size
agg.sort.each { |k, v| next if v.map { _1[2] }.uniq.size == 1 && (v.map { _1[1] }.max - v.map { _1[1] }.min) < 2000; puts "| #{k} | #{v[0][0]} | " + v.map { |c, b, n, o| "#{n} / #{(b / 1024.0).round(1)} / #{o}" }.join(" | ") + " |" }
puts "| all 114 | 114 | " + t.map { |r| "#{r.sum { _1[3].to_i }} / #{(r.sum { _1[2].to_i } / 1024.0).round} / #{r.sum { _1[4].to_i }}" }.join(" | ") + " |"
