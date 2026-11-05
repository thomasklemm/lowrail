# Compare two dump passes request by request after stripping CSRF tokens.
# Usage: ruby cmp_dumps.rb DIR_A DIR_B [--show N]
require "digest"
a, b = ARGV[0], ARGV[1]
show = ARGV.include?("--show") ? Integer(ARGV[ARGV.index("--show") + 1]) : 0

def norm(s)
  s.gsub(/(name="csrf-token" content=")[^"]+/, '\1X')
   .gsub(/(name="authenticity_token" (?:autocomplete="off" )?value=")[^"]+/, '\1X')
   .gsub(/(value=")[^"]+(" (?:autocomplete="off" )?name="authenticity_token")/, '\1X\2')
end

ia = File.readlines(File.join(a, "index.tsv")).map { _1.chomp.split("\t") }
ib = File.readlines(File.join(b, "index.tsv")).map { _1.chomp.split("\t") }
abort "different request counts #{ia.size} #{ib.size}" unless ia.size == ib.size
diffs = []
ia.zip(ib).each do |ra, rb|
  idx = ra[0]
  abort "path mismatch at #{idx}: #{ra[2]} #{rb[2]}" unless ra[2] == rb[2]
  diffs << [idx, ra[2], "status #{ra[1]}->#{rb[1]}"] unless ra[1] == rb[1]
  ba = norm(File.read(File.join(a, format("%04d.txt", idx.to_i))))
  bb = norm(File.read(File.join(b, format("%04d.txt", idx.to_i))))
  diffs << [idx, ra[2], "body #{ba.bytesize}/#{bb.bytesize}"] unless ba == bb
end
puts "#{ia.size} requests, #{ia.count { _1[1] == "200" }} with 200 in A, #{ib.count { _1[1] == "200" }} in B, #{diffs.size} differ after CSRF stripping"
diffs.each { puts diffs.first == _1 || true ? _1.join("\t") : nil }
diffs.first(show).each do |idx, path, _|
  fa = File.join(a, format("%04d.txt", idx.to_i)); fb = File.join(b, format("%04d.txt", idx.to_i))
  File.write("/tmp/na", norm(File.read(fa))); File.write("/tmp/nb", norm(File.read(fb)))
  puts "--- #{path}"; puts `diff /tmp/na /tmp/nb | head -20`
end
