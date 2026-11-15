# UA1 corpus: one user agent per line, deduplicated, in first-seen order.
#   ruby corpus.rb USERAGENT_SPEC_DIR UAP_DIR INTOLI_JSON_GZ CRAWLER_JSON > corpus.txt
# Sources (pinned 2026-11-15): useragent's spec strings (gshutler/useragent 680915a, v0.16.11),
# ua-parser/uap-core 73e7340c3e tests/test_{ua,os,device}.yaml, intoli/user-agents 8a2b6f229b
# src/user-agents.json.gz, monperrus/crawler-user-agents a727b35790 crawler-user-agents.json (instances).
require "prism"
require "yaml"
require "json"
require "zlib"

spec_dir, uap_dir, intoli, crawler = ARGV
uas = []

Dir["#{spec_dir}/**/*.rb"].sort.each do |file|
  queue = [Prism.parse_file(file).value]
  while (node = queue.shift)
    if node.is_a?(Prism::CallNode) && node.name == :parse && node.receiver&.slice == "UserAgent"
      arg = node.arguments&.arguments&.first
      uas << arg.unescaped if arg.is_a?(Prism::StringNode)
    end
    queue.concat(node.compact_child_nodes)
  end
end

%w[test_ua.yaml test_os.yaml test_device.yaml].each do |name|
  YAML.safe_load_file(File.join(uap_dir, name))["test_cases"].each { |c| uas << c["user_agent_string"] }
end

JSON.parse(Zlib::GzipReader.open(intoli, &:read)).each { |r| uas << r["userAgent"] }
JSON.parse(File.read(crawler)).each { |r| uas.concat(Array(r["instances"])) }

uas.compact.map { |s| s.b }.reject { |s| s.include?("\n") || s.include?("\r") }.uniq.each { |s| $stdout.write(s, "\n") }
