# ruby series.rb NAME DIR...: an action's (or outside-request action's) warm and window counts per run, per capture.
require "json"; require "zlib"
name = ARGV.shift
ARGV.each do |d|
  f = File.exist?("#{d}/report.json") ? File.read("#{d}/report.json") : Zlib::GzipReader.open("#{d}/report.json.gz", &:read)
  j = JSON.parse(f)
  found = []
  walk = ->(o) { case o when Hash then (found << o if o["name"] == name && o["warm"]); o.each_value(&walk) when Array then o.each(&walk) end }
  walk.(j)
  found.each { |a| puts "#{File.basename(d)}: windows #{a["windows"].inspect} warm #{a["warm"].inspect} all #{a["all"].inspect}" }
end
