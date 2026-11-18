# ruby compare_ab.rb BASE_OUT NEW_OUT NAME_BASE NAME_NEW LABEL: workload names, masked SQL digests and median
# GC-enabled objects per op of a YAML census run against a DSL one, with the YAML pair's own A/A.
require "json"
b, n, nb, nn, label = ARGV
label ||= "own"
load_run = ->(dir, name, l) { JSON.parse(File.read(File.join(dir, l, "#{name}-interpreter.json"))) }
med = ->(a) { s = a.sort; s[s.size / 2] }
b1, b2, n1, n2 = load_run.(b, nb, label), load_run.(b, nb, "#{label}2"), load_run.(n, nn, label), load_run.(n, nn, "#{label}2")
names = ->(r) { r["workloads"].map { _1["workload"] } }
puts "names equal: #{names.(b1) == names.(n1)} (#{names.(b1).size}); dsl pair names equal: #{names.(n1) == names.(n2)}"
puts (names.(b1) - names.(n1)).inspect, (names.(n1) - names.(b1)).inspect if names.(b1) != names.(n1)
printf "%-45s %9s %9s %8s %9s %9s  %-18s %s\n", "workload", "yml", "dsl", "Δ", "A/A yml", "A/A dsl", "sql", "yml windows"
names.(b1).each do |w|
  f = ->(r) { r["workloads"].find { _1["workload"] == w } }
  x, y, x2, y2 = f.(b1), f.(n1), f.(b2), f.(n2)
  next puts "#{w}: missing" unless y
  ox, oy, ox2, oy2 = [x, y, x2, y2].map { med.(_1["gc_enabled_objects_per_op"]) }
  digests = [x, x2, y, y2].map { _1.dig("sql", "digest") }
  sql = digests.uniq.size == 1 ? "same (4 runs)" : (digests[2] == digests[0] || digests[2] == digests[1] ? "same as a yml run" : "DIFF #{digests.inspect}")
  printf "%-45s %9.1f %9.1f %+8.1f %+9.1f %+9.1f  %-18s %s\n", w, ox, oy, oy - ox, ox2 - ox, oy2 - oy, sql, (x["gc_enabled_objects_per_op"] + x2["gc_enabled_objects_per_op"]).map { _1.round(1) }.minmax.inspect
end
