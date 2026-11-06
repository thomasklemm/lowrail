# jitsum.rb: blog per request kind, wall ms per iteration, mean over processes, per config.
require "json"
cfgs = %w[i409 y409 im ym zm]
data = cfgs.to_h { |c| [c, Dir["/tmp/x/wall/jit-#{c}-*.json"].map { JSON.parse(File.read(_1)) }] }
groups = { "reads (GET)" => ->(k) { k.start_with?("GET") }, "writes (POST/PATCH/DELETE)" => ->(k) { !k.start_with?("GET") },
           "  POST comment" => ->(k) { k.start_with?("POST /articles/:id/comments") }, "  POST article 302" => ->(k) { k == "POST /articles 302" },
           "  POST article 422" => ->(k) { k == "POST /articles 422" }, "  PATCH article" => ->(k) { k.start_with?("PATCH") },
           "  DELETE article" => ->(k) { k.start_with?("DELETE /articles/:id 303") }, "  GET show" => ->(k) { k == "GET /articles/:id 200" },
           "  GET index" => ->(k) { k == "GET /articles 200" } }
printf("%-28s %s\n", "ms/iteration (n procs)", cfgs.map { |c| "%-14s" % "#{c} (#{data[c].size})" }.join)
mean = ->(c, f) { data[c].sum { |j| j["kinds"].sum { |k, v| f[k] ? v : 0 } } / data[c].size }
groups.each do |g, f|
  printf("%-28s %s\n", g, cfgs.map { |c| "%-14s" % format("%.0f", mean[c, f]) }.join)
end
printf("%-28s %s\n", "total", cfgs.map { |c| "%-14s" % format("%.0f", data[c].sum { _1["total_ms"] } / data[c].size) }.join)
puts "JIT speedup (interp / JIT): "
groups.each do |g, f|
  printf("%-28s y409 %.2fx   ym %.2fx   zm %.2fx   master/4.0.9 interp %.3f\n", g, mean["i409", f] / mean["y409", f], mean["im", f] / mean["ym", f], mean["im", f] / mean["zm", f], mean["im", f] / mean["i409", f])
end
puts "process spread (total): " + cfgs.map { |c| t = data[c].map { _1["total_ms"].round }; "#{c} #{t.inspect}" }.join("  ")
