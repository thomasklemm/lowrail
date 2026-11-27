# ruby methods.rb OUT APP...: objects per request by Rails method, r81 against main, from each tree's
# lowrail-profile report (its "ranked" sites, warm counts, mean of the runs). A site's method is the innermost
# `def` around its line in that tree's Rails source (rails.txt names the commit; RAILS_REPO is a rails/rails clone),
# so lines that moved between the trees still match. Prints each app's objects per request and median action
# change, then the Rails methods that moved by at least MIN (default 5) objects per request in an app.
require "json"
require "prism"
require "zlib"
out = ARGV.shift
min = Float(ENV.fetch("MIN", "5"))
repo = ENV.fetch("RAILS_REPO", "/home/user/r82/rails-main")
def report(dir)
  path = %w[report.json report.json.gz].map { File.join(dir, _1) }.find { File.exist?(_1) }
  path && JSON.parse(path.end_with?(".gz") ? Zlib::GzipReader.open(path, &:read) : File.read(path))
end
defs = Hash.new do |h, (sha, path)|
  src = IO.popen(["git", "-C", repo, "show", "#{sha}:#{path}"], err: File::NULL, &:read)
  found = []
  walk = lambda do |node, scope|
    next unless node
    case node
    when Prism::ClassNode, Prism::ModuleNode then scope = "#{scope}#{node.constant_path.slice}::"
    when Prism::DefNode then found << [node.location.start_line, node.location.end_line, "#{scope}#{node.name}"]
    end
    node.compact_child_nodes.each { walk.(_1, scope) }
  end
  walk.(Prism.parse(src).value, "") unless src.empty?
  h[[sha, path]] = found
end
method_of = lambda do |sha, site|
  path, line = site.delete_prefix("RAILS/").split(/:(?=\d+\z)/)
  hit = defs[[sha, path]].select { |a, b, _| (a..b).cover?(line.to_i) }.min_by { |a, b, _| b - a }
  "#{path} #{hit ? hit[2] : "(top level)"}"
end
mean = ->(a) { a.compact.sum.fdiv([a.compact.size, 1].max) }
moves = Hash.new { |h, k| h[k] = {} }
puts "| App | objects/request r81 | main | Δ | actions in both | median action Δ |"
puts "| --- | ---: | ---: | ---: | ---: | ---: |"
ARGV.each do |app|
  dirs = %w[r81 main].map { File.join(out, app, _1) }
  r = dirs.map { report(File.join(_1, "profiled")) }
  next puts("| #{app} | missing | | | | |") unless r.all?
  shas = dirs.map { |d| File.read(File.join(d, "rails.txt"))[/\h{40}/] }
  totals = r.map { |rep| mean.(rep["summary"].map { _1["objects_per_request"] }) }
  acts = r.map { |rep| rep["actions"].filter_map { [_1["name"], mean.(_1["warm"])] if _1["warm"]&.all? }.to_h }
  common = acts[0].keys & acts[1].keys
  deltas = common.map { acts[1][_1] - acts[0][_1] }.sort
  med = deltas.empty? ? nil : deltas[deltas.size / 2]
  puts "| #{app} | #{totals[0].round(1)} | #{totals[1].round(1)} | #{(totals[1] - totals[0]).round(1)} | #{common.size} | #{med&.round(1)} |"
  by = r.zip(shas).map do |rep, sha|
    rep["ranked"].select { _1["site"].start_with?("RAILS/") && _1["warm"] }.each_with_object(Hash.new(0.0)) do |row, acc|
      acc[method_of.(sha, row["site"])] += mean.(row["warm"])
    end
  end
  (by[0].keys | by[1].keys).each do |k|
    moves[k][app] = [by[0][k], by[1][k]] if (by[1][k] - by[0][k]).abs >= min
  end
end
puts
puts "| Rails method | apps | r81 → main objects per request |"
puts "| --- | ---: | --- |"
moves.sort_by { |_, apps| -apps.values.sum { |a, b| b - a } }.first(Integer(ENV.fetch("TOP", "40"))).each do |k, apps|
  puts "| `#{k}` | #{apps.size} | #{apps.sort_by { |_, (a, b)| a - b }.map { |app, (a, b)| "#{app} #{a.round(1)} → #{b.round(1)}" }.join(", ")} |"
end
