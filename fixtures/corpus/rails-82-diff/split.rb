a = File.foreach(ARGV[0], mode: "rb").to_h { |l| k, v = l.chomp.split("\t", 2); [k, v] }
b = File.foreach(ARGV[1], mode: "rb").to_h { |l| k, v = l.chomp.split("\t", 2); [k, v] }
pre = ARGV[2]
cnt = Hash.new { |h, k| h[k] = [] }
a.each do |k, v|
  next unless k.start_with?(pre) && v != b[k]
  w = b[k].to_s
  kind = if v.start_with?("!") && w.start_with?("!") then (v[/\A![^:]+/] == w[/\A![^:]+/] ? "same-error-new-message" : "different-error")
         elsif v.start_with?("!") then "8.1 raised, main returns"
         elsif w.start_with?("!") then "8.1 returns, main raises"
         else "different value" end
  cnt[kind] << k
end
cnt.each { |kind, ks| puts "#{kind}: #{ks.size}"; ks.first(3).each { |k| puts "  #{k}\n    8.1:  #{a[k][0, 300]}\n    main: #{b[k].to_s[0, 300]}" } }
