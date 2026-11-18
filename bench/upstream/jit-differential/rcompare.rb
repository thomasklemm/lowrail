# rcompare.rb DIR: per-test failures in Ruby's own suite logs (btest, test-all, test-spec, test-bundled-gems),
# each mode compared against interp-0; tests that already differ between interp-0 and interp-1 are marked.
dir = ARGV.fetch(0)
def failures(path)
  s = File.read(path, encoding: "binary").scrub
  set = {}
  s.scan(/^\s*\d+\) (?:Failure|Error):\n(\S+?#\S+?)(?: \[|:$)/) { set[$1] = true }
  s.scan(/^\d+\)\n(.+) (FAILED|ERROR)$/) { set["#{$1} #{$2}"] = true }
  s.scan(/^(#\d+ \S+\.rb:\d+):/) { set[$1] = true }
  s.scan(/^(\S+(?:-\d[\w.]*)?) failed\b/) { set["gem #{$1}"] = true }
  set["[BUG]"] = true if s.include?("[BUG]")
  set["worker crashed"] = true if s =~ /worker.*crash|Some worker was crashed/i
  summary = s.scan(/^(\d+ tests?, \d+ assertions, \d+ failures, \d+ errors, \d+ skips)|^(\d+ files?, \d+ examples?, \d+ expectations?, \d+ failures?, \d+ errors?, \d+ taggeds?)|^(PASS all \d+ tests|FAIL \d+\/\d+ tests failed)/).flatten.compact.last
  [set, summary]
end
logs = Dir["#{dir}/*.log"].sort
base_logs = logs.select { File.basename(_1).start_with?("interp") }
abort "no interp log in #{dir}" if base_logs.empty?
base, = failures(base_logs.first)
flaky = {}
base_logs.drop(1).each { |f| b, = failures(f); (base.keys | b.keys).each { flaky[_1] = true if base[_1] != b[_1] } }
logs.each do |f|
  d, sum = failures(f)
  diffs = (base.keys | d.keys).reject { base[_1] == d[_1] }
  puts "#{File.basename(f, '.log')}: #{sum || 'NO SUMMARY'}; #{d.size} failing, #{diffs.size} diffs#{" (#{diffs.count { flaky[_1] }} interp-flaky)" if diffs.any? { flaky[_1] }}"
  diffs.each { puts "  #{base[_1] ? 'interp-only' : 'mode-only'}: #{_1}#{' [interp-flaky]' if flaky[_1]}" } if f != base_logs.first
end
