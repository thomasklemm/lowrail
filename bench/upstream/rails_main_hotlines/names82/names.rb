# ruby names.rb OLD.json NEW.json: per surface, names that are new in every visibility (an app can pick them),
# names that moved visibility, and names removed from the surface. Names starting with "_" are counted, not listed.
require "json"
old, new = ARGV.map { JSON.parse(File.read(_1)) }
puts "# Rails #{old["rails"]} (#{old["rails_sha"][0, 10]}) to #{new["rails"]} (#{new["rails_sha"][0, 10]}), #{new["ruby"]}"
vis_of = ->(lists, n) { lists.select { |_, ns| ns.include?(n) }.keys }
total_new = []
new["surface"].each do |surface, lists|
  was = old["surface"][surface]
  names, old_names = lists.values.flatten.uniq, was.values.flatten.uniq
  added, removed = names - old_names, old_names - names
  moved = (names & old_names).select { vis_of.(lists, _1).sort != vis_of.(was, _1).sort }
  hidden = added.count { _1.start_with?("_") }
  shown = added.reject { _1.start_with?("_") }
  total_new.concat(shown)
  next if shown.empty? && moved.empty? && removed.empty?
  puts "\n## #{surface}: #{shown.size} new (+#{hidden} underscore), #{moved.size} moved, #{removed.size} removed"
  puts "new: " + shown.map { "#{_1}(#{vis_of.(lists, _1).join("/")})" }.join(" ") if shown.any?
  puts "moved: " + moved.map { "#{_1}(#{vis_of.(was, _1).join("/")}->#{vis_of.(lists, _1).join("/")})" }.join(" ") if moved.any?
  puts "removed: " + removed.reject { _1.start_with?("_") }.map { "#{_1}(#{vis_of.(was, _1).join("/")})" }.join(" ") if removed.any?
end
puts "\n## #{total_new.uniq.size} distinct non-underscore names new to at least one surface"
