# Per-scenario table from results/MODE.txt: main runs (main x2, main2), their spread (max-min over min, the A/A),
# and each head against the median main run, marked * when outside the spread. Under a JIT, a scenario whose window
# compiled anything in any tree is marked nf (not JIT-flat) and doesn't count. Usage: ruby table.rb MODE
rows = Hash.new { |h, k| h[k] = Hash.new { |g, t| g[t] = [] } }
compiled = Hash.new(0)
File.foreach(File.join(__dir__, "results", "#{ARGV.fetch(0)}.txt")) do |line|
  tree, _rev, _mode, *rest = line.split
  next compiled[rest[1..-2].join(" ")] += Integer(rest.last) if rest.first == "jit_window"
  rows[rest[0..-2].join(" ")][tree] << Integer(rest.last)
end
puts format("%-32s %10s %7s  %-18s %-18s %-18s", "scenario", "main med", "A/A", "TO1", "FH2", "LBL1")
rows.each do |name, by|
  mains = by["main"] + by["main2"]
  med = mains.sort[mains.size / 2]
  aa = (mains.max - mains.min).fdiv(mains.min) * 100
  cells = %w[to1 fh2 lbl1].map do |t|
    v = by[t].first or next "-"
    d = (v - med).fdiv(med) * 100
    format("%9d %+6.2f%%%s", v, d, d.abs > aa ? "*" : " ")
  end
  puts format("%-32s %10d %6.2f%%  %-18s %-18s %-18s%s", name, med, aa, *cells, compiled[name] > 0 ? " nf" : "")
end
