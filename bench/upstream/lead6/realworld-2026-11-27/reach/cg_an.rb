# ruby cg_an.rb FILE.jsonl: Ir per op for each workload (N window dumps at index 1, 3, ...), per arm, vs main, A/A main2.
require "json"
rows = File.readlines(ARGV[0]).map { JSON.parse(_1) }
wl = rows.first["results"].map { _1["workload"] }
wl.each_with_index do |w, i|
  by = rows.group_by { _1["arm"] }.transform_values { |rs| rs.map { |r| r["ir"][2 * i + 1].fdiv(r["results"][i]["n"]) } }
  obj = rows.group_by { _1["arm"] }.transform_values { |rs| rs.map { _1["results"][i]["objects"] } }
  m = by[ENV.fetch("BASE", "main")].sum / by[ENV.fetch("BASE", "main")].size
  puts "== #{w}"
  by.each { |arm, xs| puts format("  %-6s Ir/op mean %12.0f  min %12.0f max %12.0f  vs main %+6.2f%%  objects %s", arm, xs.sum / xs.size, xs.min, xs.max, 100 * (xs.sum / xs.size / m - 1), obj[arm].minmax.join("..")) }
  puts "  JIT-flat: #{rows.all? { _1["results"][i]["jit_flat"] }}"
end
