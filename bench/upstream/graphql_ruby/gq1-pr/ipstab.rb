# ipstab.rb DIR : i/s per scenario from ips.sh outputs. Best of all rounds per revision, and the A/A:
# best of the first half of the rounds against best of the second half, for each revision.
dir = ARGV.fetch(0)
runs = Dir["#{dir}/*-*.txt"].map { |f| File.basename(f, ".txt").split("-") }.map { |r, rev| [r.to_i, rev] }
rounds = runs.map(&:first).uniq.sort
ips = ->(r, rev) do
  File.read("#{dir}/#{r}-#{rev}.txt").split("Calculating").last.scan(/^\s*(validate - [^\n]+?)\s+([\d.]+)(k?) \(/)
    .to_h { |name, v, k| [name.strip, v.to_f * (k == "k" ? 1000 : 1)] }
end
data = rounds.to_h { |r| [r, %w[master head].to_h { |rev| [rev, ips.(r, rev)] }] }
half = rounds.each_slice((rounds.size / 2.0).ceil).to_a
puts "rounds: #{rounds.size}; best of all rounds; A/A = best of rounds #{half[0].join(',')} vs #{half[1].join(',')}"
puts "scenario | master | head | head/master | master A/A | head A/A"
data[rounds.first]["master"].each_key do |s|
  best = ->(rev, rs) { rs.map { |r| data[r][rev][s] }.max }
  m, h = best.("master", rounds), best.("head", rounds)
  aa = ->(rev) { format("%+.1f%%", 100.0 * (best.(rev, half[1]) / best.(rev, half[0]) - 1)) }
  puts format("%s | %.1f | %.1f | %.2fx | %s | %s", s, m, h, h / m, aa.("master"), aa.("head"))
end
