# man.rb micro.jsonl: per shape, exits per window (stats run), and per process the median of paired window
# differences (on − off, in pair order), for the timed and the A/A processes; cost per exit = difference / exits.
require "json"
rows = File.foreach(ARGV[0]).map { JSON.parse(_1) }
med = ->(a) { s = a.sort; s[s.size / 2] }
rows.group_by { _1["shape"] }.each do |shape, rs|
  st = rs.find { _1["run"] == "stats" }
  n = st["on"].size
  epw = st["on_exits"].to_f / n
  printf("%-6s exits per window: on %.1f, off %.2f; median window off %.1f µs\n", shape, epw, st["off_exits"].to_f / n,
    med.(rs.select { _1["run"] == "timed" }.flat_map { _1["off"] }) * 1e6)
  %w[timed aa].each do |run|
    d = rs.select { _1["run"] == run }.map { |r| med.(r["on"].zip(r["off"]).map { |a, b| a - b }) * 1e6 }
    printf("   %-5s Δ per window µs %s => per exit %s ns\n", run, d.map { "%+.2f" % _1 }.join(" "),
      d.map { "%+.0f" % (_1 * 1000 / epw) }.join(" "))
  end
end
