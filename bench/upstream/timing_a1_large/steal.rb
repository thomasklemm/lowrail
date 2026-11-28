# Per-interval steal and busy share from the /proc/stat snapshot log (statlog.sh); cpu = aggregate, cpu1 = bench core.
snaps = File.read(ARGV[0]).split(/^T /).reject(&:empty?).map do |b|
  t, *lines = b.lines
  [t.to_i, lines.to_h { |l| f = l.split; [f[0], f[1..].map(&:to_i)] }]
end
rows = snaps.each_cons(2).map do |(t0, a), (t1, b)|
  %w[cpu cpu0 cpu1].to_h do |c|
    d = b[c].zip(a[c]).map { _1 - _2 }; tot = d[0, 8].sum.to_f
    [c, { steal: d[7] / tot, busy: (tot - d[3] - d[4]) / tot }]
  end.merge(t: t1)
end
ARGV[1..].each_slice(3) do |label, from, to|
  r = rows.select { (from.to_i..to.to_i).cover?(_1[:t]) }
  next puts("#{label}: no samples") if r.empty?
  avg = ->(c, k) { r.sum { _1[c][k] } / r.size * 100 }
  mx = r.map { _1["cpu"][:steal] * 100 }.max
  printf "%-10s n=%3d steal all %.3f%% (max %.2f%%) cpu1 %.3f%% | busy all %.1f%% cpu0 %.1f%% cpu1 %.1f%%\n", label, r.size,
    avg.("cpu", :steal), mx, avg.("cpu1", :steal), avg.("cpu", :busy), avg.("cpu0", :busy), avg.("cpu1", :busy)
end
