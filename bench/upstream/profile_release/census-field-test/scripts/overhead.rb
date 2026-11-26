# ruby overhead.rb OUTDIR: suite time ("Finished in", per run) of plain/plain2 against run 1 (counting) and
# run 2 (attribution) of every unchanged capture u*, and wall time from summary.txt.
dir = ARGV.fetch(0)
times = ->(name) { File.exist?(f = File.join(dir, "#{name}.log")) ? File.read(f, invalid: :replace).scan(/Finished in (?:(\d+) minutes? )?([\d.]+) ?s/).map { |m, s| m.to_i * 60 + s.to_f } : [] }
plain = times.("plain") + times.("plain2")
abort "#{dir}: no plain suite times" if plain.empty?
base = plain.sum / plain.size
wall = File.readlines(File.join(dir, "summary.txt")).filter_map { |l| [$1, $2.to_f] if l =~ /\A(\S+) exit \d+ wall ([\d.]+)/ }.to_h
caps = Dir["#{dir}/u*.log"].map { File.basename(_1, ".log") }.sort_by { _1[1..].to_i }
r = caps.map { times.(_1) }.reject { _1.size < 2 }
pct = ->(t) { format("%+.0f%%", 100 * (t / base - 1)) }
mean = ->(a) { a.sum / a.size }
r1, r2 = r.map(&:first), r.map(&:last)
cw = caps.filter_map { wall[_1] }
puts "#{File.basename(dir)}: plain #{plain.map { _1.round(1) }.join(", ")} s; run 1 mean #{mean.(r1).round(1)} s (#{pct.(mean.(r1))}); " \
  "run 2 mean #{mean.(r2).round(1)} s (#{pct.(mean.(r2))}); wall plain #{wall["plain"]&.round(1)} s, a capture #{mean.(cw).round(1)} s " \
  "(#{(mean.(cw) / wall["plain"]).round(1)}x) over #{cw.size} captures" unless r.empty? || cw.empty?
