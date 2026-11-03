# compare.rb DIR : compare all *.json in DIR against interp-*.json
require "json"
dir = ARGV[0]
norm = ->(k) { k.gsub(/0x\h+/, "0x").gsub(/\d{4}-\d\d-\d\d[ _T]\d\d:\d\d:\d\d(\.\d+)?/, "TS").gsub(/\w{3},_\d\d_\w{3}_\d{4}_\d\d:\d\d:\d\d/, "TS").gsub(/Date:_\d{4}-\d\d-\d\d/, "Date:") }
load = ->(f) { JSON.parse(File.read(f))["tests"].transform_keys(&norm) rescue nil }
files = Dir["#{dir}/*.json"].sort
base_files = files.select { File.basename(_1).start_with?("interp") }
base = load.(base_files.first)
abort "no baseline in #{dir}" unless base
flaky = {}
base_files.drop(1).each { |f| b = load.(f); next unless b; (base.keys | b.keys).each { |k| flaky[k] = true if base[k]&.dig("r") != b[k]&.dig("r") } }
(files - [base_files.first]).each do |f|
  d = load.(f)
  name = File.basename(f, ".json")
  unless d
    puts "#{name}: NO OUTCOMES (crash?)"; next
  end
  diffs = (base.keys | d.keys).select { base[_1]&.dig("r") != d[_1]&.dig("r") }
  puts "#{name}: #{d.size} tests, #{diffs.size} result diffs#{diffs.count { flaky[_1] }.then { _1 > 0 ? " (#{_1} also flaky in interp)" : "" }}"
  diffs.first(40).each { |k| puts "  #{k}: #{base[k]&.dig('r') || 'MISSING'} -> #{d[k]&.dig('r') || 'MISSING'} #{flaky[k] ? '[interp-flaky]' : ''}\n    #{d[k]&.dig('m') || base[k]&.dig('m')}" }
end
