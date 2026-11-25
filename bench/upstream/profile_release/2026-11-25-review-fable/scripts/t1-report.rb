# t1-report.rb REPORT.json : where each fixture's allocation line landed.
require "json"
r = JSON.parse(File.read(ARGV[0]))
marks = { "inner" => 11, "gitlab_like" => 13, "vendored" => 17, "outer" => 19, "linked.rb" => 23, "deep" => 29, "gitgem" => 31, "loose" => 37 }
all_ranked = r["ranked"]
marks.each do |name, n|
  hits = all_ranked.select { _1["site"].include?(name.delete_suffix(".rb")) && _1["site"] =~ /(#{name.delete_suffix(".rb")})\.rb:2|deep\.rb:3/ }
  rows = r["rows"].select { |row| hits.any? { _1["site"] == row["site"] } }
  app = r["app_lines"].select { _1["line"].include?("/#{name.delete_suffix(".rb")}.rb") }
  puts "#{name} (#{n}/req): ranked=#{hits.map { [_1["site"], _1["group"], _1["all"]] }.inspect} top_rows=#{rows.map { [_1["site"], _1["callers"]] }.inspect} app_lines=#{app.map { [_1["line"], _1["own"], _1["warm"]] }.inspect}"
end
puts "unclassified=#{r["unclassified"].inspect}"
puts "groups=" + r["groups"].map { [_1["group"], _1["all"] || _1["warm"]] }.inspect
ctrl = r["app_lines"].select { _1["line"].include?("articles_controller") }
puts "controller lines=" + ctrl.map { [_1["line"], _1["warm"], _1["own"], _1["sites"]] }.inspect
puts "unattributed=#{r["unattributed"].inspect}"
