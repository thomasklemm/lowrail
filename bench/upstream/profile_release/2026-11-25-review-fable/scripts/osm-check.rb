# osm-check.rb DIR : the README's OSM numbers from the committed captures, through the built gem's compare.
require "json"; require "open3"
dir = ARGV[0]
cmp = lambda do |b, h, a|
  out, status = Open3.capture2("lowrail-profile", "compare", "#{dir}/#{b}.json", "#{dir}/#{h}.json", "--aa", "#{dir}/#{a}.json", "--json")
  [status.exitstatus, JSON.parse(out)]
end
serial = %w[s1 s2 s3 s4]
flagged = 0; total = 0
serial.permutation(3) { |b, a, h| s, r = cmp.(b, h, a); raise "exit #{s}" unless s == 0; total += 1; flagged += 1 if r["regressions"].any? }
puts "one process, unchanged: #{flagged} of #{total} heads with a listed regression"
found = 0; n = 0; rows = nil
serial.permutation(2) { |b, a| s, r = cmp.(b, "s5", a); n += 1; hit = r["regressions"].find { _1["name"] == "NotesController#index" }; found += 1 if hit; rows ||= hit }
puts "plant: NotesController#index listed in #{found} of #{n}; first: delta #{rows["delta"].round(1)} floor #{rows["noise_floor"].round(1)} base #{rows["base"].inspect}"
s, r = cmp.("base", "head", "aa")
puts "8 workers: exit #{s}; #{r["problems"].first.to_s[0, 90]}"
%w[base aa head].each { |c| j = JSON.parse(File.read("#{dir}/#{c}.json")); a = j["actions"].find { _1["name"] == "NotesController#index" }; puts "#{c}: processes #{j["summary"].map { _1["processes"] }.inspect} NotesController#index warm #{a["warm"].inspect}" }
