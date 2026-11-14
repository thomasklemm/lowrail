# ruby kw_sweep_report.rb LABEL=DIR ...   (DIR has cases.json and cg.<pid>.<n> dumps)
require "json"

def total(path) = File.foreach(path).find { _1.start_with?("totals:", "summary:") }.split[1].to_i

cols = ARGV.map do |arg|
  label, dir = arg.split("=", 2)
  data = JSON.parse(File.read(File.join(dir, "cases.json")))
  base = Dir[File.join(dir, "cg.*.1")].first.sub(/\.1\z/, "")
  ir = data["cases"].to_h { |c| [[c["shape"], c["size"]], (total("#{base}.#{c["dump"]}") - total("#{base}.#{c["seam"]}")).fdiv(c["n"])] }
  [label, ir]
end
keys = cols.first[1].keys
puts "| shape | size | " + cols.map(&:first).join(" | ") + (cols.size > 1 ? " | " + cols[1..].map { "#{_1[0]} vs #{cols[0][0]}" }.join(" | ") : "") + " |"
puts "|---|---:|" + "---:|" * (cols.size * 2 - 1)
keys.each do |k|
  vals = cols.map { _2[k] }
  rel = vals[1..].map { format("%+.1f%%", (_1 / vals[0] - 1) * 100) }
  puts "| `#{k[0]}` | #{k[1]} | " + vals.map { format("%.0f", _1) }.join(" | ") + (rel.empty? ? "" : " | " + rel.join(" | ")) + " |"
end
