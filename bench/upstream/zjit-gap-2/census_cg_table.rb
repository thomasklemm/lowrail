# frozen_string_literal: true

# Ir per operation from script/census run --callgrind (docs/upstream/zjit-gap-census-2.md).
#   ruby SCRIPT OUT_DIR
# OUT_DIR holds one label per build and app (z2cg-BUILD-APP and its A/A twin z2cg-BUILD-APP2), each with
# APP-MODE.json and the Callgrind dumps APP-MODE.cg.PID.N. The used window is the last attempt; its Ir minus the
# empty window (dump 1), divided by the window's operations. Prints one row per build and app, and the gate.
# Runs measure after the same number of cycles (CENSUS_CG_MIN_WINDOWS = CENSUS_CG_MAX_WINDOWS, one attempt), because
# workloads that write rows do more work in later cycles. App workloads keep creating ISEQs (both JITs compile a few per window, docs/upstream/zjit-iseq-leads.md F1-c), so
# windows often fail the JIT-flat gate; the table therefore reports Ir without compilation, profiling and
# invalidation (COMPILE_ROOTS), which is what A/A is judged on, and the total next to it.
require "json"

# Compilation, profiling and invalidation entry points; their inclusive Ir (with the compiler's malloc and memcpy,
# which the self-Ir buckets would count as runtime) is left out of the steady-state figure.
COMPILE_ROOTS = /:(rb_zjit_compile_iseq|zjit::codegen::function_stub_hit|rb_zjit_profile_insn|rb_zjit_invalidate_\w+|rb_yjit_compile_iseq|yjit::core::(?:branch|entry)_stub_hit|rb_yjit_invalidate_\w+) \[/
def steady_ir(path)
  out = IO.popen(["callgrind_annotate", "--inclusive=yes", "--threshold=100", "--auto=no", path], &:read)
  total = out[/^\s*([\d,]+) \(100\.0%\)\s+PROGRAM TOTALS/, 1].delete(",").to_f
  total - out.each_line.sum { |line| line.match?(COMPILE_ROOTS) ? line[/\A\s*([\d,]+)/, 1].delete(",").to_f : 0 }
end

def total_ir(path) = File.foreach(path).grep(/\Atotals: /).first.split.last.to_f

out = ARGV.fetch(0)
ir = lambda do |json_path|
  d = JSON.parse(File.read(json_path))
  used = d["attempts"].last
  dump = ->(n) { Dir[json_path.sub(/\.json\z/, ".cg.#{d["pid"]}.#{n}")].first }
  [(steady_ir(dump.(used["dump"])) - steady_ir(dump.(1))) / d["ops"], used["gate"], d["attempts"].size,
    (total_ir(dump.(used["dump"])) - total_ir(dump.(1))) / d["ops"]]
end

rows = Hash.new { |h, k| h[k] = {} }
Dir[File.join(out, "z2cg-*")].each do |dir|
  label = File.basename(dir)
  next unless (m = label.match(/\Az2cg-(.+)-([a-z]+?)(2?)\z/))
  build, app, twin = m[1], m[2], m[3] == "2" ? "b" : "a"
  Dir[File.join(dir, "#{app}-*.json")].each do |json|
    mode = File.basename(json, ".json").split("-").last
    rows[[app, build]][[mode, twin]] = ir.(json)
  end
end

puts "| app | build | YJIT a / b | ZJIT a / b | A/A YJIT, ZJIT | ZJIT vs YJIT | with compile | gates |"
puts "| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |"
rows.sort.each do |(app, build), r|
  cell = ->(mode) { %w[a b].map { r[[mode, _1]] ? format("%.3f", r[[mode, _1]][0] / 1e6) : "–" }.join(" / ") }
  mean = ->(mode) { xs = %w[a b].filter_map { r[[mode, _1]]&.first }; xs.empty? ? nil : xs.sum / xs.size }
  aa = ->(mode) { xs = %w[a b].filter_map { r[[mode, _1]]&.first }; xs.size == 2 ? format("%.2f%%", 100 * (xs.max - xs.min) / mean.(mode)) : "–" }
  vs = mean.("zjit") && mean.("yjit") ? format("%+.1f%%", 100 * (mean.("zjit") / mean.("yjit") - 1)) : "–"
  all = ->(mode) { xs = %w[a b].filter_map { r[[mode, _1]]&.last }; xs.empty? ? nil : xs.sum / xs.size }
  vs_all = all.("zjit") && all.("yjit") ? format("%+.1f%%", 100 * (all.("zjit") / all.("yjit") - 1)) : "–"
  gates = r.sort.map { |(mode, twin), (_, gate, n)| "#{mode}#{twin} #{gate}#{" (#{n} attempts)" if n > 1}" }.join(", ")
  puts "| #{app} | #{build} | #{cell.("yjit")} | #{cell.("zjit")} | #{aa.("yjit")}, #{aa.("zjit")} | **#{vs}** | #{vs_all} | #{gates} |"
end
