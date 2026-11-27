# ruby cross.rb BASE_LABEL HEAD_LABEL [PAIRS] [OUT.json]  -- per-test outcome differences between two Ruby builds (docs/upstream/ruby41-differential-409.md).
# PAIRS: comma list of head_mode:base_mode (default interp:interp,yjit:yjit,interpw:interpw,zjit:interp)
require "json"
require "zlib"
load File.expand_path("../../../script/ruby-differential", __dir__) unless defined?(RubyDifferential)
RD = RubyDifferential
base, head, pairs = ARGV
pairs = (pairs || "interp:interp,yjit:yjit,interpw:interpw,zjit:interp").split(",").map { _1.split(":") }
out = {}
apps = Dir[File.join(RD.out_dir(head), "*")].select { File.directory?(_1) }.map { File.basename(_1) }.sort
apps.each do |app|
  pairs.each do |hm, bm|
    hf, bf = File.join(RD.out_dir(head), app, "#{hm}.json.gz"), File.join(RD.out_dir(base), app, "#{bm}.json.gz")
    next unless File.exist?(hf) && File.exist?(bf)
    h, b = RD.read_gz(hf), RD.read_gz(bf)
    if h["tests"].nil? || b["tests"].nil?
      puts "#{app} #{hm} vs #{bm}: NO OUTCOMES head exit=#{h["exit"]} base exit=#{b["exit"]}"
      out["#{app} #{hm}"] = { "no_outcomes" => true, "head_exit" => h["exit"], "base_exit" => b["exit"] }
      next
    end
    bt, ht = RD.keyed(b["tests"]), RD.keyed(h["tests"])
    diffs = (bt.keys | ht.keys).select { RD.differs?(bt[_1], ht[_1]) }
    puts "#{app} #{hm} vs #{bm}: base #{bt.size} #{b["tests"].values.map(&:first).tally} exit=#{b["exit"]} | head #{ht.size} #{h["tests"].values.map(&:first).tally} exit=#{h["exit"]} jit=#{h["jit"].slice("yjit", "zjit")}: #{diffs.size} differ"
    diffs.first(15).each { |k| puts "    #{k[0, 140]}\n      base=#{bt[k]&.first(3).inspect[0, 200]}\n      head=#{ht[k]&.first(3).inspect[0, 200]}" }
    out["#{app} #{hm}"] = { "base_mode" => bm, "tests" => ht.size, "differ" => diffs.map { |k| { "id" => k, "base" => bt[k]&.first(4), "head" => ht[k]&.first(4) } } }
  end
end
File.write(ARGV[3] || "/tmp/cross.json", JSON.pretty_generate(out))
