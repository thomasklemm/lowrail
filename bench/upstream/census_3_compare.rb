require "json"
dir = "/home/user/workspace/repo/.lowrail/private/rails-main-census-3"
base = ARGV[0] == "base" ? dir : File.join(dir, "after-#{ARGV[0]}")
after = File.join(dir, "after-#{ARGV[1]}")
sites = ARGV.drop(2).map { |s| f, l = s.split(":"); [f, Integer(l)] }
med = ->(a) { a.sort[1] }
%w[blog campfire fizzy writebook].each do |app|
  %w[interpreter yjit].each do |mode|
    a = JSON.parse(File.read(File.join(base, "#{app}-#{mode}.json")))
    b = JSON.parse(File.read(File.join(after, "#{app}-#{mode}.json")))
    a["routes"].zip(b["routes"]).each do |ra, rb|
      gc = med.(rb["gc_enabled_objects_per_request"]) - med.(ra["gc_enabled_objects_per_request"])
      tr = (rb["traced_gc_objects"] - ra["traced_gc_objects"]) / ra["requests"].to_f
      s = sites.map { |f, l| sa = ra["sites"].select { _1["file"].end_with?(f) && _1["line"] == l }.sum { _1["objects_per_request"] }; sb = rb["sites"].select { _1["file"].end_with?(f) && _1["line"] == l }.sum { _1["objects_per_request"] }; "#{File.basename(f)}:#{l} #{sa}->#{sb}" }
      printf "%-9s %-11s %-45s gc %+8.2f traced %+8.1f  %s\n", app, mode, ra["route"][0, 45], gc, tr, s.join("  ")
    end
  end
end
