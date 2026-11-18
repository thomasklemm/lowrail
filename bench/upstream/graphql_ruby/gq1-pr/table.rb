# table.rb DIR : per-iteration Ir per scenario from cgrun.sh outputs (DIR/REV-REP.SCEN.N.out),
# reps a/b of each revision as A/A, and head against master.
dir = ARGV.fetch(0)
sc = { "val_abstract" => [10, 40], "val_big" => [5, 20], "val_merge" => [1, 4], "val_intro" => [10, 40],
       "next_intro" => [5, 20], "next_small" => [20, 80], "next_large" => [1, 3], "int_intro" => [2, 8],
       "exe_intro_big" => [2, 6] }
ir = ->(t, s, n) { f = "#{dir}/#{t}.#{s}.#{n}.out"; File.exist?(f) ? File.read(f)[/^(?:summary|totals): (\d+)/, 1].to_i : nil }
fmt = ->(x) { x.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
puts "scenario | master a / b (A/A) | head a / b (A/A) | head vs master"
sc.each do |s, (a, b)|
  means = {}
  cells = %w[master head].map do |rev|
    reps = %w[a b].map { |r| (x = ir.("#{rev}-#{r}", s, b)) && (y = ir.("#{rev}-#{r}", s, a)) ? (x - y) / (b - a) : nil }
    next "n/a" if reps.compact.size < 2
    means[rev] = reps.sum / 2.0
    format("%s / %s (%.2f%%)", fmt.(reps[0]), fmt.(reps[1]), 100.0 * (reps[0] - reps[1]).abs / means[rev])
  end
  d = means.size == 2 ? format("%+.2f%%", 100.0 * (means["head"] - means["master"]) / means["master"]) : "n/a"
  puts "#{s} | #{cells.join(' | ')} | #{d}"
end
