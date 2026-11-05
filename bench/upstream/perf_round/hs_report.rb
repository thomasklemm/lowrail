# ruby hs_report.rb FILE.json... : Rails hash sites that spill to an st_table (memsize > 160 B), and objects > 30 ivars
require "json"
ARGV.each do |f|
  j = JSON.parse(File.read(f))
  puts "== #{File.basename(f)} (#{j["ruby"][0, 40]})"
  rows = j["hashes"].select { |k, s| k.start_with?("RAILS/") && s["st"] > 0 }
  rows.sort_by { |_, s| -s["st"] }.first(Integer(ENV.fetch("N", 25))).each do |k, s|
    sizes = s["sizes"].sort_by { |sz, _| sz.to_i }.map { |sz, c| "#{sz}:#{c}" }.first(6).join(" ")
    printf("%6d spill/%6d  mean %.1f keys  %6.0f B  %s  [%s]\n", s["st"], s["count"], s["size"] / s["count"].to_f, s["memsize"] / s["count"].to_f, k, sizes)
  end
  puts "-- wide objects (> 30 ivars)"
  j["wide"].sort_by { |_, w| -w["count"] }.first(10).each { |k, w| printf("%6d  %-60s ivars %s  %.0f B\n", w["count"], k, w["ivars"].to_a.inspect, w["memsize"] / w["count"].to_f) }
end
