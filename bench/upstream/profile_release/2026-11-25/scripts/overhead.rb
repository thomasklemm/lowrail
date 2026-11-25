# ruby overhead.rb OUTDIR...: suite time as each suite reports it ("Finished in"), plain and off against both runs
# of each capture (run 1 counts; run 2 also walks the stack per allocation), and wall time from summary.txt.
ARGV.each do |dir|
  times = ->(name) { File.exist?(f = File.join(dir, "#{name}.log")) ? File.read(f).scan(/Finished in ([\d.]+) ?s/).flatten.map(&:to_f) : [] }
  plain = (times.("plain") + times.("plain2"))
  base = plain.sum / plain.size
  wall = File.readlines(File.join(dir, "summary.txt")).to_h { |l| l =~ /\A(\S+) exit \d+ wall ([\d.]+)/ ? [$1, $2.to_f] : [nil, nil] }.compact
  pct = ->(t) { format("%+.0f%%", 100 * (t / base - 1)) }
  captures = %w[profiled base2 head].map { times.(_1) }.reject(&:empty?)
  r1, r2 = captures.map(&:first), captures.map(&:last)
  puts "#{File.basename(dir)}: plain #{plain.map { _1.round(1) }.join(", ")} s; off #{times.("off").map { _1.round(1) }.join(", ")} s; " \
    "run 1 #{r1.map { _1.round(1) }.join(", ")} s (#{pct.(r1.sum / r1.size)}); run 2 #{r2.map { _1.round(1) }.join(", ")} s (#{pct.(r2.sum / r2.size)}); " \
    "wall plain #{wall["plain"]&.round(1)} s, a capture #{%w[profiled base2 head].filter_map { wall[_1]&.round(1) }.join(", ")} s"
end
