# frozen_string_literal: true

# Export counts/controls/provenance, never response bodies, cookies or sessions.
require_relative "../request_pairs"
root = File.expand_path("../..", __dir__)
app = File.join(root, ".corpus/real-blog-r4")
interpreter, yjit, destination = ARGV.map { File.expand_path(_1) }
raise "usage: sealed_renderer_report.rb INTERPRETER_DIR YJIT_DIR OUTPUT_JSON [OBSERVER_DIR]" unless destination
stages = %w[off_a off_b L2_events restored form filters tokens collection]
result = {schema_version: 1, report_sha256: Digest::SHA256.file(__FILE__).hexdigest,
  protocol: "six fresh rounds, seed 41231, N=0/50, fixed five pools, <=4 workers",
  boot_failure: {directory: "/tmp/sealed-renderer-interpreter", collected_ir: 0,
    explanation: "Four first-wave workers failed before warmup/windows: after_initialize ran before route loading. Move installation after completed boot. No completed round or A/A result was replaced."},
  scope_probe: {totals: [28119, 4637933, 13898010],
    ratio: (13898010 - 28119).fdiv(4637933 - 28119),
    explanation: "Selected nested work 0/10000/30000, unselected 80000 each; exception unwind balanced. Expected independent work ratio: 3."}}
{"interpreter" => interpreter, "yjit" => yjit}.each do |mode, directory|
  raw = JSON.parse(File.read(File.join(directory, "samples.json")))
  summary = JSON.parse(File.read(File.join(directory, "summary.json")))
  provenance = JSON.parse(File.read(File.join(directory, "provenance.json")))
  raise "measured sources changed" unless provenance.fetch("sources").all? { |path, sha|
    Digest::SHA256.file(File.join(root, path)).hexdigest == sha }
  raise "fixture sources changed" unless provenance.fetch("fixture_sources").all? { |path, sha|
    Digest::SHA256.file(File.join(app, path)).hexdigest == sha }
  raise "lock changed" unless Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest == provenance.fetch("lock_sha256")
  rows = raw.fetch("samples")
  estimate = ->(values) { RequestPairs.estimate(values, seed: 41231) }
  table = stages.each_with_index.to_h do |stage, index|
    values = %w[instructions_total instructions_no_gc allocations].to_h do |metric|
      [metric, estimate.call(rows.map { _1.fetch(stage).fetch(metric) })]
    end
    previous = index >= 3 ? stages.fetch(index - 1) : "off_a"
    values[:delta_from_previous_ir] = estimate.call(rows.map { _1.fetch(stage).fetch("instructions_total") - _1.fetch(previous).fetch("instructions_total") })
    values[:delta_vs_rails_pct] = estimate.call(rows.map { 100 * (_1.fetch(stage).fetch("instructions_total") / _1.fetch("off_a").fetch("instructions_total") - 1) })
    [stage, values]
  end
  checks = stages.drop(3).to_h do |stage|
    off, on = %w[off on].map { JSON.parse(File.read(File.join(directory, "#{stage}-checks", "#{_1}.json"))) }
    left, right = [off, on].map { _1.fetch("responses") }
    raise "export refuses unequal pairs" unless left == right && left.size == 192
    [stage, {pairs: left.size, identical: true, hits: on.fetch("specimen_hits"),
      digest: Digest::SHA256.hexdigest(JSON.generate(left)),
      fields: %w[status body all_headers ordered_SQL_with_binds_and_cached_flags controller_render_events assigns transaction query_cache]}]
  end
  accepted = summary.dig("aa", "pass") && summary.fetch("heap_matched") && summary.dig("jit", "pass")
  # Keep every endpoint once, not twice in both samples and worker metadata.
  export_rows = rows.each_with_index.map do |row, round|
    row.to_h do |arm, metrics|
      raise "window copies disagree" unless metrics.fetch("windows") == raw.fetch("workers").fetch("#{round}-#{arm}").fetch("windows")
      [arm, metrics.reject { |key, _| key == "windows" }]
    end
  end
  data = {accepted: accepted, table: table, checks: checks, provenance: provenance,
    summary: summary, window_endpoints: "raw.workers[round-arm].windows",
    raw: raw.merge("samples" => export_rows)}
  if mode == "interpreter"
    scope_windows = raw.fetch("workers").select { |name, _| name.include?("-residual_") }.values.flat_map { _1.fetch("windows") }
    raise "scope counters require GC-free windows" unless scope_windows.all? { |window|
      %w[minor_gc_count major_gc_count].all? { window.fetch("before").fetch(_1) == window.fetch("after").fetch(_1) } }
    data[:residual_boundaries] = %w[residual_all residual_AR residual_security residual_fanout].to_h do |stage|
      [stage, %w[instructions_total instructions_no_gc].to_h do |metric|
        [metric, estimate.call(rows.map { _1.fetch(stage).fetch(metric) })]
      end]
    end
    data[:residual_accepted] = false
    data[:residual_caveat] = "Diagnostic inclusive boundary prices. Wrappers perturb full-request work; not a self partition or removable floor. Allocation endpoints in raw scope workers describe the WHOLE request, not the selected boundary."
    data[:residual_wrapper_overhead_ir] = estimate.call(rows.map {
      _1.fetch("residual_all").fetch("instructions_total") - _1.fetch("collection").fetch("instructions_total") })
  end
  result[mode] = data
end
if ARGV[3]
  off, on = %w[off on].map { JSON.parse(File.read(File.join(ARGV.fetch(3), "#{_1}.json"))) }
  raise "observer pairs differ" unless off.fetch("responses") == on.fetch("responses") && on.fetch("responses").size == 192
  raise "observer did not run" unless on.fetch("responses").any? { _1.fetch("headers")["x-render-observer"] == "live" }
  result[:side_effecting_observer] = {pairs: 192, identical: true, hits: on.fetch("specimen_hits"),
    digest: Digest::SHA256.hexdigest(JSON.generate(on.fetch("responses")))}
end
File.write(destination, JSON.pretty_generate(result) + "\n")
result.each do |mode, data|
  next unless %w[interpreter yjit].include?(mode)
  puts "#{mode}: #{data[:accepted] ? 'accepted' : 'REJECTED'}"
  data[:table].each { |name, row| puts "#{name}: #{row.inspect}" }
  puts "residual: #{data[:residual_boundaries].inspect}" if data[:residual_boundaries]
end
