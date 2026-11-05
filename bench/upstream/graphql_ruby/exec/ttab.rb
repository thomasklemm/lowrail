# ttab.rb "v1 v2" : tracked-scenario per-iteration Ir from cg.sh outputs t<v>-<rep>
vs = ARGV[0].split
sc = { "val_abstract" => [10, 40], "val_abstract2" => [10, 40], "val_big" => [5, 20], "val_merge" => [1, 4], "next_intro" => [5, 20], "next_small" => [20, 80], "next_large" => [1, 3], "int_intro" => [2, 8] }
ir = ->(t, s, n) { f = "/tmp/cg/#{t}.#{s}.#{n}.out"; File.exist?(f) ? File.read(f)[/^summary: (\d+)/, 1].to_i : nil }
fmt = ->(x) { x.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
sc.each do |s, (a, b)|
  base = nil
  row = vs.map do |v|
    reps = %w[a b].map { |r| (x = ir.("t#{v}-#{r}", s, b)) && (y = ir.("t#{v}-#{r}", s, a)) ? (x - y) / (b - a) : nil }.compact
    next "#{v} n/a" if reps.empty?
    m = reps.sum / reps.size
    base ||= m
    format("%s %s / %s (A/A %.2f%%, %+.2f%%)", v, fmt.(reps[0]), fmt.(reps[1] || 0), 100.0 * (reps[0] - (reps[1] || reps[0])).abs / m, 100.0 * (m - base) / base)
  end
  puts "#{s}: " + row.join(" | ")
end
