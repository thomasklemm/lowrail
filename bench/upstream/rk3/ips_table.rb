# ruby ips_table.rb OUTDIR [MODE]: best-of-rounds calls/s per expression, main vs branch, and main's spread across
# rounds (the A/A), from ips.sh's JSON files.
dir, mode = ARGV[0], ARGV[1] || "interp"
require "json"
best = Hash.new { |h, k| h[k] = Hash.new { |g, s| g[s] = [] } }
Dir["#{dir}/*-#{mode}-*.json"].each do |f|
  side = File.basename(f)[/\A(main|branch)/]
  JSON.parse(File.read(f)).each { |r| best[r["name"]][side] << r["central_tendency"] }
end
puts "| #{mode} | main | branch | | main A/A |", "| --- | ---: | ---: | ---: | ---: |"
best.each do |name, s|
  m, b = s["main"].max, s["branch"].max
  aa = (s["main"].max / s["main"].min - 1) * 100
  printf("| `%s` | %s | %s | %.2fx | %.1f%% |\n", name, m.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse,
    b.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse, b / m, aa)
end
