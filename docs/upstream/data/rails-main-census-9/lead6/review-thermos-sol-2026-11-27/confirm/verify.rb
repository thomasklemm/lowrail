require "json"

evidence = File.expand_path("..", __dir__)
item = File.read(File.join(__dir__, "item-reviewed.md"))
record = File.read(File.join(__dir__, "record-reviewed.md"))
body = item.split(/^---\s*$/).last
raise "wrong head" unless item.include?('head: "8b1c6428ea056b3c5983372d85b85615ae3d3f45"')

benchmark = body.match(/```ruby\n(.*?)\n```/m).captures.first
original = File.read(File.join(evidence, "native_benchmark.rb")).sub(/\A# frozen_string_literal: true\n\n/, "").strip
raise "benchmark changed" unless benchmark == original
raise "unexpected code comment" if benchmark.lines.any? { |line| line.lstrip.start_with?("#") }
puts "BENCHMARK_MATCHES_EXECUTED_SCRIPT_WITHOUT_MAGIC_COMMENT"

%w[before after].zip(%w[ips-r2-base.log ips-r1-candidate.log]).each do |label, file|
  printed = body.lines.find { |line| line.start_with?("#{label}:") }.sub(/\A#{label}:\s*/, "").strip
  raw = File.read(File.join(evidence, "body-rerun/raw", file))
  measured = raw.lines.grep(/serializable_hash.* i\/s/).last.strip
  raise "native output mismatch: #{label}" unless printed == measured
  puts "NATIVE_OUTPUT_MATCHES #{label}: #{file}"
end

data = JSON.parse(File.read(File.join(evidence, "body-rerun/results.json")))
ips = data.fetch("ips").fetch("serializable_hash")
raise "wrong base" unless data.dig("sides", "base", "head") == "088fc0cf61e4ba0c7987decafacc69adb3e22eec"
raise "wrong candidate" unless data.dig("sides", "candidate", "head") == "8b1c6428ea056b3c5983372d85b85615ae3d3f45"
raise "native gate failed" unless ips.dig("jit", "flat") && ips.dig("jit", "windows").length == 9
ips.fetch("rounds").each do |side, values|
  field = side == "base" ? "base1" : side
  raise "not best round: #{side}" unless values.max == ips.fetch(field)
end
puts "BEST_ROUNDS_AND_NINE_JIT_FLAT_WINDOWS_VERIFIED"
puts "Native aggregate: controls #{ips.fetch('base1')} / #{ips.fetch('base2')}, mean #{ips.fetch('base')}; head #{ips.fetch('candidate')}"
puts "Aggregate change #{(100 * ips.fetch('change')).round(4)}%; A/A #{(100 * ips.fetch('aa')).round(4)}%; distinct from the two displayed raw lines"

heading = "Callgrind instructions per call, Ruby 4.0, no JIT:"
old_heading = "Callgrind instructions per call, Ruby 4.0, no JIT, objects per call unchanged:"
old_body = File.read(File.join(evidence, "item-reviewed.md")).split(/^---\s*$/).last
raise "instruction claims changed" unless body.split(heading).last == old_body.split(old_heading).last
raise "wrong heading" unless body.include?(heading)
raise "blanket allocation claim" if body.include?("objects per call unchanged")
puts "INSTRUCTION_TABLE_AND_FINAL_INSTRUCTION_PROSE_UNCHANGED"

objects = "Objects per call are unchanged for find then `changed?` and `serializable_hash` (90 and 32). The two base allocation runs differ for `update!`, so no allocation count is claimed for that row."
ungated = "These are ungated observations; without an invalidation counter, the runs do not establish a ZJIT gain or rule out a regression."
raise "record allocation qualification missing" unless record.include?(objects)
raise "record ZJIT qualification missing" unless record.include?(ungated)
raise "record counter claims remain" if record.match?(/No ZJIT loss|--zjit-stats|600,000|zjit_insn_count/)
impact = item.lines.find { |line| line.start_with?("impact:") }
raise "impact allocation qualification missing" unless impact.include?("update!'s base runs differ, no claim")
raise "impact ZJIT qualification missing" unless impact.include?("neither establish a gain nor rule out a regression")
raise "impact counter claim remains" if impact.include?("fewer sends")
puts "ALLOCATION_AND_ZJIT_FINDINGS_RESOLVED_IN_RECORD_AND_IMPACT"

keys = "In the measured `update!` of one column, dirty tracking calls `#keys` three times and `#[]` once for each attribute it checks."
raise "keys qualification missing" unless body.include?(keys)
raise "missing native lead" unless body.index("A benchmark of serializing a record from a 30-column table:") < body.index(heading)
raise "internal review text upstream" if body.match?(/Lowrail|thermos-sol|A\/A|No ZJIT loss/)
puts "SCOPED_KEYS_SENTENCE_AND_NATIVE_LEAD_PRESENT"
puts "ASSEMBLED_BODY_CONFIRM_CHECKS_PASS"
