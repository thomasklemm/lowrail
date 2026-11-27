# ruby diff.rb OLD.json NEW.json: names added and removed per surface and visibility, per reserved-name set, and for
# each added surface name the framework modules that newly define it (from the per-module lists).
require "json"
old, new = ARGV.map { JSON.parse(File.read(_1)) }
puts "# Method names, Rails #{old["rails"]} (#{old["rails_sha"][0, 10]}) to #{new["rails"]} (#{new["rails_sha"][0, 10]})"
puts "# #{new["ruby"]}"

owners = Hash.new { |h, k| h[k] = [] }
new["modules"].each do |mod, lists|
  before = old["modules"][mod] || {}
  lists.each { |vis, names| (names - (before[vis] || [])).each { owners[_1] << "#{mod}#{vis.start_with?("singleton") ? "." : "#"}(#{vis})" } }
end

puts "\n## Reserved-name sets"
new["reserved"].each do |set, names|
  next unless names.is_a?(Array)
  was = old["reserved"][set]
  puts "#{set}: +#{(names - was).size} -#{(was - names).size}"
  puts "  + #{(names - was).join(" ")}" if (names - was).any?
  puts "  - #{(was - names).join(" ")}" if (was - names).any?
end

puts "\n## Surfaces (+ added, - removed; owners for added names)"
new["surface"].each do |surface, lists|
  lists.each do |vis, names|
    was = old.dig("surface", surface, vis) || []
    added, removed = names - was, was - names
    next if added.empty? && removed.empty?
    puts "\n### #{surface} #{vis}: +#{added.size} -#{removed.size}"
    added.each { puts "+ #{_1}  [#{owners[_1].uniq.first(3).join(", ")}]" }
    removed.each { puts "- #{_1}" }
  end
end

all_added = new["surface"].flat_map { |s, l| l.flat_map { |v, n| n - (old.dig("surface", s, v) || []) } }.uniq.sort
all_removed = old["surface"].flat_map { |s, l| l.flat_map { |v, n| n - (new.dig("surface", s, v) || []) } }.uniq.sort
puts "\n## Totals: #{all_added.size} distinct names added to some surface, #{all_removed.size} removed from some surface"
