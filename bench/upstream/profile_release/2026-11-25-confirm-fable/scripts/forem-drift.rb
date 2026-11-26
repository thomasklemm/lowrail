# forem-drift.rb : Forem's base, A/A and head captures (one process, the same commit, about 30 minutes apart, from
# bench/upstream/oss_profile_sweep_1/forem): how far an action's warm objects per request differ between base and head.
require "json"; require "zlib"
dir = File.expand_path("../../../oss_profile_sweep_1/forem", __dir__)
dir = ARGV[0] if ARGV[0]
b, h, a = %w[base head aa].map { |d| JSON.parse(Zlib::GzipReader.open("#{dir}/#{d}/report.json.gz", &:read)) }
mean = ->(r) { r["actions"].select { _1["warm"].is_a?(Array) && _1["warm"].all?(Numeric) }.to_h { [_1["name"], _1["warm"].sum / _1["warm"].size] } }
mb, mh, ma = mean.(b), mean.(h), mean.(a)
common = (mb.keys & mh.keys & ma.keys).select { mb[_1] > 0 }
rel = common.map { |n| [n, (mh[n] - mb[n]).abs / mb[n] * 100, mh[n] - mb[n], mb[n]] }
big = rel.select { _3.abs >= 20 }
puts "actions with a warm value in base, A/A and head: #{common.size}"
puts "base and head 20 or more objects apart: #{big.size}; their relative difference: median #{big.map { _2 }.sort[big.size / 2].round(2)}%, largest #{big.map { _2 }.max.round(2)}%"
puts "0.5% or more: #{rel.count { _2 >= 0.5 }}; 0.2% or more: #{rel.count { _2 >= 0.2 }}; 0.1% or more: #{rel.count { _2 >= 0.1 }}"
puts "what compare listed (forem-compare.txt):"
File.readlines("#{dir}/forem-compare.txt").grep(/^\| request action/).each do |row|
  _, _, name, base, head, delta, = row.split("|").map(&:strip)
  puts "  #{name}: #{base} -> #{head} (#{delta}, #{(delta.to_f.abs / base.to_f * 100).round(2)}%)"
end
