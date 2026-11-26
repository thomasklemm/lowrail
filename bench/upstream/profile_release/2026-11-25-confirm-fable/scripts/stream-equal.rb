# stream-equal.rb OLD_LIB NEW_LIB DIR : the report of kept runs in DIR built by the lib of 1618fc38 and by the new
# one, in two processes; what differs in report.json and report.md.
require "json"; require "open3"; require "digest"
old, new, dir = ARGV
build = lambda do |lib|
  out, err, status = Open3.capture3(RbConfig.ruby, "-I#{lib}", "-rlowrail/profile_report", "-rjson", "-e",
    'r = Lowrail::ProfileReport.new(ARGV[0], top: 400); puts JSON.generate("json" => r.to_h, "md" => r.markdown, "rss_kb" => File.read("/proc/self/status")[/VmHWM:\s+(\d+)/, 1].to_i)', dir)
  abort err unless status.success?
  JSON.parse(out)
end
a, b = build.(old), build.(new)
puts "peak RSS: old #{a["rss_kb"] / 1024} MB, new #{b["rss_kb"] / 1024} MB"
diff = lambda do |x, y, path|
  if x.is_a?(Hash) && y.is_a?(Hash) then (x.keys | y.keys).flat_map { |k| diff.(x[k], y[k], "#{path}/#{k}") }
  elsif x.is_a?(Array) && y.is_a?(Array) && x.size == y.size then x.each_index.flat_map { |i| diff.(x[i], y[i], "#{path}[#{i}]") }
  else x == y ? [] : ["#{path}: #{x.inspect[0, 90]} -> #{y.inspect[0, 90]}"]
  end
end
d = diff.(a["json"], b["json"], "")
puts "report.json: #{d.size} differing values"; d.first(12).each { puts "  #{_1}" }
old_md, new_md = a["md"].lines, b["md"].lines
puts "report.md: #{old_md.size} and #{new_md.size} lines, #{old_md.zip(new_md).count { |x, y| x != y }} differ"
old_md.zip(new_md).select { |x, y| x != y }.first(4).each { |x, y| puts "  - #{x.to_s[0, 160].chomp}\n  + #{y.to_s[0, 160].chomp}" }
