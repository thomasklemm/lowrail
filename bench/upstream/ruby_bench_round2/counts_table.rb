# Summarize per-iteration JIT compile counts from jit_counts.sh output.
# usage: counts_table.rb FILE... ; window = WARMUP+1 .. WARMUP+N (defaults 15, 10)
W = Integer(ENV.fetch("W", "15")); N = Integer(ENV.fetch("N", "10"))
ARGV.each do |f|
  rows = File.readlines(f).grep(/^\s*#\d+:/).map do |l|
    a = l.split
    [a[0].delete("#:").to_i, a[1].to_i, *a[2..].map { _1.delete(",").to_i }]
  end
  next puts("#{File.basename(f)}: no rows") if rows.empty?
  yjit = f.include?("yjit")
  # columns: itr, ms, then stats in order given by jit_counts.sh
  units = yjit ? rows.map { _1[2] } : rows.map { _1[2] }          # blocks (YJIT) or ISEQs (ZJIT)
  iseqs = yjit ? rows.map { _1[3] } : rows.map { _1[2] }
  ctime = yjit ? rows.map { _1[5] } : rows.map { _1[4] }
  ms = rows.map { _1[1] }
  last = rows.rindex { |r| (yjit ? r[2] : r[2]) > 0 }
  win = (W...(W + N))
  quiet_from = (0...rows.size).find { |i| units[i..].all?(&:zero?) }
  cum = units.sum
  share = ->(r) { units[r].sum.fdiv(cum) * 100 }
  wms = ms[win].sum; wct = ctime[win].sum / 1e6
  late = ->(r) { r.select { units[_1] > 0 }.size }
  puts format("%-26s itrs=%d last_compile_itr=%s quiet_from=%s | window %d-%d: %s=%d iseqs=%d itrs_with_compiles=%d/%d compile=%.1fms of %dms (%.2f%%) | after window: itrs_with_compiles=%d/%d units=%d | mean ms 6-15=%d 16-25=%d 26-40=%d 41-%d=%d",
    File.basename(f, ".txt"), rows.size, last ? last + 1 : "-", quiet_from ? quiet_from + 1 : "never",
    W + 1, W + N, yjit ? "blocks" : "iseqs", units[win].sum, iseqs[win].sum, late.(win), N, wct, wms, wct / wms * 100,
    late.((W + N)...rows.size), rows.size - W - N, units[(W + N)..].sum,
    ms[5...15].sum / 10, ms[15...25].sum / 10, ms[25...40].sum / 15, rows.size, ms[40..].sum / [ms[40..].size, 1].max)
end
