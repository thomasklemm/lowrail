# ruby ir_table.rb OUTDIR N  -> per case/mode: Ir per call for main, aa, cand (medians over reps)
out, n = ARGV[0], Integer(ARGV[1] || 3000)
ir = ->(f) { File.read(f)[/Collected : (\d+)/, 1]&.to_i }
rows = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
Dir["#{out}/*-#{n}.out"].each do |f|
  base = File.basename(f, "-#{n}.out")
  c, v, m = base.match(/\A(.+)-(main|aa|cand)(\d+)-(\w+)\z/).values_at(1, 2, 4)
  zero = f.sub(/-#{n}\.out\z/, "-0.out")
  a, z = ir.(f), (File.exist?(zero) ? ir.(zero) : nil)
  next unless a && z
  rows[[c, m]][v] << (a - z).fdiv(n)
end
med = ->(a) { s = a.sort; s[s.size / 2] }
order = %w[i49 y49 i41 z41]
rows.sort_by { |(c, m), _| [c, order.index(m) || 9] }.each do |(c, m), v|
  next if %w[main aa cand].any? { v[_1].empty? }
  a, aa, b = med.(v["main"]), med.(v["aa"]), med.(v["cand"])
  printf "%-20s %-4s main %10.0f  A/A %+6.2f%%  cand %10.0f  %+7.2f%%   (reps %d)\n", c, m, a, (aa / a - 1) * 100, b, (b / a - 1) * 100, v["main"].size
end
