# ruby table.rb APP...: one Markdown row per app from ~/hl-out/APP (summary, report.json) and apps/APP.sh.
require "json"
here = __dir__
ARGV.each do |a|
  out = File.expand_path("~/hl-out/#{a}")
  conf = File.read(File.join(here, "apps/#{a}.sh"))
  ruby = conf[/^RUBY=(\S+)/, 1]
  cmd = conf[/^CMD=\((.*)\)$/, 1].gsub('"', "")
  lock = File.read("/home/user/workspace/repo/.corpus/hl-#{a}/Gemfile.lock")
  rails = lock[/^    (?:rails|actionpack) \(([^)]+)\)/, 1]
  summary = File.read(File.join(out, "summary.txt"))
  totals = summary[/^plain\.log: .*?; (.*)$/, 1].to_s.split(" | ").first
  same = summary[/^profiled\.log: (identical.*|DIFFERS.*)$/, 1]
  report = File.join(out, "profiled/report.json")
  counted = File.exist?(report) ? File.read(File.join(out, "profiled/report.md"))[/Counted in run 1: ([^;]+);/, 1] : "no report"
  wall = summary.scan(/^(plain|profiled) exit (\d+) wall ([\d.]+)/).to_h { [_1, [_2, _3.to_f.round]] }
  puts "| #{a} | #{ruby}, #{rails} | `#{cmd}` | #{totals} | #{same&.sub(/ \(each of.*/, '')} | #{counted} | #{wall['plain']&.last}s / #{wall['profiled']&.last}s |"
end
