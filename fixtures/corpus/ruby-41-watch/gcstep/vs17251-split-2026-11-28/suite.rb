# ruby suite.rb [OUT] -- one line per ruby-bench benchmark and mode from OUT/split (default ~/w/out): majors over the
# whole run (base/base2/head/nocad medians), nofree majors summed over rounds (base/head), and paired-by-round
# percentage differences, median (min..max): head - base with the A/A base2 - base beside it, and nocad - base.
require "json"
OUT = File.join(ARGV[0] || File.expand_path("~/w/out"), "split")
def med(a) = (s = a.sort; s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0)
B = %w[base base2 head nocad]
benches = Dir["#{OUT}/*/*.json"].map { File.basename(_1, ".json").sub(/-(interp|yjit|zjit)$/, "") }.uniq.sort
get = ->(v, r, b, m) { f = "#{OUT}/#{v}-#{r}/#{b}-#{m}.json"; File.exist?(f) ? JSON.parse(File.read(f)) : nil }
by = ->(j) { g = j["gcs"] || []; g.each_with_object(Hash.new(0)) { |x, h| h[x[0]] += 1 if x[0] } }
metric = {
  "itr" => ->(j) { med(j["times_s"]) * 1000 }, "hwm" => ->(j) { j["vmhwm_kb"] / 1024.0 },
  "steady" => ->(j) { med(j["rss_kb"]) / 1024.0 }, "afterGC" => ->(j) { j["rss_kb_after_full_gc"] / 1024.0 },
  "maj" => ->(j) { j["run"]["major_gc_count"] }, "gcms" => ->(j) { j["bench"]["time"] } }
puts "bench mode | majors whole run b/b2/h/n | nofree whole run b/h | itr% h-b (A/A b2-b) | HWM MiB b/b2/h/n | HWM% h-b, n-b (A/A) | steady% h-b (A/A) | afterGC% h-b (A/A)"
benches.each do |b|
  %w[interp yjit zjit].each do |m|
    js = B.to_h { |v| [v, (1..3).map { get.(v, _1, b, m) }] }
    next if js.values.flatten.any?(&:nil?)
    mm = ->(k, v) { med(js[v].map(&metric[k])) }
    pc = ->(k, a, c) { d = (0..2).map { (metric[k].(js[a][_1]) / metric[k].(js[c][_1]) - 1) * 100 }; "%+.0f(%+.0f..%+.0f)" % [med(d), d.min, d.max] }
    nf = ->(v) { js[v].sum { by.(_1)["nofree"] } }
    printf("%s %s | %s | %d/%d | %s (%s) | %s | %s, %s (%s) | %s (%s) | %s (%s) nocad %s\n", b, m,
      B.map { "%.0f" % mm.("maj", _1) }.join("/"), nf.("base"), nf.("head"),
      pc.("itr", "head", "base"), pc.("itr", "base2", "base"),
      B.map { "%.1f" % mm.("hwm", _1) }.join("/"), pc.("hwm", "head", "base"), pc.("hwm", "nocad", "base"), pc.("hwm", "base2", "base"),
      pc.("steady", "head", "base"), pc.("steady", "base2", "base"), pc.("afterGC", "head", "base"), pc.("afterGC", "base2", "base"), pc.("afterGC", "nocad", "base"))
  end
end
