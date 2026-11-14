# table.rb OUT [RUN]: Markdown table per mode of Ir per call for every case and width: main, A/A (main2 against
# main), fix against main and fixb against main, objects per call, and the JIT gate of each tree's window.
require "json"

out, run = ARGV.fetch(0), ARGV.fetch(1, "a")
rows = Dir["#{out}/*.#{run}.jsonl"].flat_map { |f| File.readlines(f).map { JSON.parse(_1) } }
by = rows.group_by { |r| [r["mode"], r["width"] || "req", r["case"]] }

def pct(x, base) = format("%+.2f%%", (x - base) * 100.0 / base)

%w[interp yjit minterp zjit].each do |mode|
  keys = by.keys.select { |m, _, c| m == mode && c != "_empty" }
  next if keys.empty?
  puts "\n### #{mode}\n\n| width | case | main Ir | A/A | value! only (fix) | branch (fixb) | objects main/fixb | gate main/main2/fix/fixb |"
  puts "|---|---|---:|---:|---:|---:|---|---|"
  keys.sort_by { |_, w, c| [w.to_s.rjust(4), c] }.each do |key|
    t = by[key].to_h { |r| [r["tree"], r] }
    main = t["main"] or next
    cells = %w[main2 fix fixb].map { |tr| t[tr] ? pct(t[tr]["ir"], main["ir"]) : "-" }
    gates = %w[main main2 fix fixb].map { |tr| t.dig(tr, "gate") || "-" }.join("/")
    objs = "#{main["objects"]}/#{t.dig("fixb", "objects")}"
    puts "| #{key[1]} | #{key[2]} | #{main["ir"]} | #{cells.join(" | ")} | #{objs} | #{gates} |"
  end
end
