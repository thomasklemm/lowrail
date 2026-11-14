# frozen_string_literal: true

# Lead 6: attr_sweep.sh results for main, the fix, K1 and K1 + the fix, with A/A twins.
#   ruby compare.rb DIR WIDTH   (files DIR/TREE-interp-wWIDTH.txt; Ir/call and objects/call per case)
dir, w = ARGV
read = ->(t) { File.readlines("#{dir}/#{t}-interp-w#{w}.txt").to_h { |l| n, ir, o = l.split; [n, [ir.to_f, o.to_f]] } }
t = %w[main fix fixb k1 k1fix k1fixb].to_h { [_1, read.(_1)] }
pct = ->(a, b) { format("%+.1f%%", (a / b - 1) * 100) }
puts "| Case (#{w} cols) | main | fix | fix vs main | A/A | K1 | K1 + fix | vs K1 | A/A | objects K1 → K1 + fix |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
t["main"].each_key do |c|
  m, f, fb, k, kf, kfb = %w[main fix fixb k1 k1fix k1fixb].map { t[_1].fetch(c) }
  puts "| `#{c}` | #{m[0].round} | #{f[0].round} | #{pct.(f[0], m[0])} | #{format("%.2f%%", ((fb[0] / f[0] - 1) * 100).abs)} | " \
       "#{k[0].round} | #{kf[0].round} | #{pct.(kf[0], k[0])} | #{format("%.2f%%", ((kfb[0] / kf[0] - 1) * 100).abs)} | #{k[1]} → #{kf[1]} |"
end
