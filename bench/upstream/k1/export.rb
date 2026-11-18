# frozen_string_literal: true

# export.rb DIR TREE MODE: JSONL rows for one run.sh arm from DIR's stdout and Callgrind dumps (cg.PID.N).
# Ir per window is each dump's trailing `totals:` line; Valgrind 3.19 can wrap `summary:` after repeated
# zero/dump client requests (docs/bench.md). A dump without `totals:` fails the export.
require "json"

dir, tree, mode = ARGV
ir = {}
Dir["#{dir}/cg.*.*"].each do |f|
  text = File.read(f)
  name = text[/^desc: Trigger: Client Request: (.*)$/, 1] or next
  ir[name] = Integer(text[/^totals: (\d+)$/, 1] || abort("missing Callgrind totals: #{f}"))
end
rows = File.readlines("#{dir}/stdout").map { JSON.parse(_1) }
empty = ir.fetch("_empty").fdiv(rows.first["n"])
rows.each do |r|
  r["ir"] = (ir.fetch(r["case"]).fdiv(r["n"]) - empty).round
  puts JSON.generate(r.merge("tree" => tree, "mode" => mode))
end
