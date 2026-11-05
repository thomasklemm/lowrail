# vtab.rb "tag1 tag2 ..." -> per-iteration Ir per scenario, reps a/b, and change vs first tag
tags = ARGV[0].split
sc = { "val_abs2" => [10, 40], "val_abs" => [10, 40], "val_big" => [5, 20], "val_intro" => [10, 40], "exe_intro_big" => [2, 6], "exe_large" => [1, 3], "exe_small" => [20, 80], "parse_intro" => [10, 40] }
sc.select! { |k, _| ARGV[1].nil? || ARGV[1].split.include?(k) }
ir = ->(t, s, n) { f = "/tmp/cg/#{t}.#{s}.#{n}.out"; File.exist?(f) ? File.read(f)[/^summary: (\d+)/, 1].to_i : nil }
fmt = ->(x) { x.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
sc.each do |s, (a, b)|
  base = nil
  row = tags.map do |t|
    reps = %w[a b].map { |r| (x = ir.("#{t}-#{r}", s, b)) && (y = ir.("#{t}-#{r}", s, a)) ? (x - y) / (b - a) : nil }.compact
    next "#{t} n/a" if reps.empty?
    m = reps.sum / reps.size
    aa = reps.size == 2 ? format("%.2f%%", 100.0 * (reps[0] - reps[1]).abs / m) : "-"
    base ||= m
    format("%s %s (A/A %s, %+.2f%%)", t, fmt.(m), aa, 100.0 * (m - base) / base)
  end
  puts "#{s}: " + row.join(" | ")
end
