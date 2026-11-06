# railswall.rb: per-process means of the alternated r81/main runs, ratio and Welch t-test p (normal approx via t, df Welch).
require "json"
d = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
Dir["/tmp/x/wall/rails-*-*/output_001.json"].each do |f|
  v = f[%r{rails-(\w+)-\d}, 1]
  JSON.parse(File.read(f))["raw_data"][v].each { |b, r| d[b][v] << r["bench"].sum / r["bench"].size * 1000 }
end
def stats(x) = [m = x.sum / x.size, x.sum { (_1 - m)**2 } / (x.size - 1)]
d.each do |b, h|
  (ma, va), (mb, vb) = stats(h["r81"]), stats(h["main"])
  t = (ma - mb) / Math.sqrt(va / h["r81"].size + vb / h["main"].size)
  printf("%-10s r81 %7.1f ms (sd %.1f%%) %s  main %7.1f ms (sd %.1f%%) %s  main/r81 %.3f  t %.1f\n", b, ma, 100 * Math.sqrt(va) / ma, h["r81"].map(&:round).inspect, mb, 100 * Math.sqrt(vb) / mb, h["main"].map(&:round).inspect, mb / ma, t)
end
