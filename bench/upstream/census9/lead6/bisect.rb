# frozen_string_literal: true

# Lead 6: trisect first-parent commits (one SHA per line in LIST, oldest first) for the first commit whose
# update1 Ir per column, (Ir@300 - Ir@30) / 270, exceeds THRESHOLD. LO is known below, HI above (0-based).
#   ruby bisect.rb LIST LO HI THRESHOLD OUT
list, lo, hi, threshold, out = ARGV
shas = File.readlines(list, chomp: true)
lo, hi, threshold = Integer(lo), Integer(hi), Float(threshold)
point = File.expand_path("point.sh", __dir__)
slope = lambda do |i|
  a, b = IO.popen([point, out, shas[i]], &:read).split.drop(1).map(&:to_i)
  s = (b - a) / 270.0
  puts format("%5d %s %9d %9d %8.0f", i, shas[i][0, 10], a, b, s)
  $stdout.flush
  s
end
while hi - lo > 1
  mids = [lo + (hi - lo) / 3, lo + 2 * (hi - lo) / 3].uniq.reject { _1 == lo || _1 == hi }
  mids = [(lo + hi) / 2] if mids.empty?
  results = mids.map { |i| Thread.new { [i, slope.(i)] } }.map(&:value)
  results.each { |i, s| s > threshold ? (hi = [hi, i].min) : (lo = [lo, i].max) }
end
puts "first above: #{hi} #{shas[hi]}"
