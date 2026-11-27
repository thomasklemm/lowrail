# frozen_string_literal: true

# First-parent bisect of one census workload's interpreter Ir/op between two
# Rails commits, through script/cpu-census (fixed heap from heap.sh). Each
# step runs the app's whole workload list, as the census does, because a
# workload's cost can depend on the workloads before it (ONLY=1: --only).
#   ruby bisect.rb APP WORKLOAD GOOD BAD [OUT]
# Each step measures one first-parent commit of the local .corpus/rails
# checkout; it is bad when its Ir/op is nearer BAD's than GOOD's. Results are
# appended to OUT/APP.tsv; already measured commits are read back, not rerun.
require "json"
require "fileutils"

ROOT = File.expand_path("../../..", __dir__)
RAILS = File.join(ROOT, ".corpus/rails")
app, workload, good, bad, out = ARGV
out ||= File.join(ROOT, ".lowrail/private/cpu-bisect#{"-only" if ENV["ONLY"]}")
FileUtils.mkdir_p(out)
git = ->(*a) { IO.popen(["git", "-C", RAILS, *a], &:read).strip }
good, bad = git.("rev-parse", good), git.("rev-parse", bad)
log = File.join(out, "#{app}.tsv")

measure = lambda do |sha|
  label = "b-#{sha[0, 12]}"
  json = File.join(out, label, "#{app}-interpreter.json")
  unless File.exist?(json)
    ok = system("mise", "exec", "ruby@4.0.9", "--", File.join(ROOT, "script/cpu-census"), "run", "--out", out, "--label", label,
      "--rails", "#{RAILS}@#{sha}", "--apps", app, "--modes", "interp", "--jobs", "1", *(["--only", workload] if ENV["ONLY"]), chdir: ROOT)
    abort "#{sha}: cpu-census failed" unless ok && File.exist?(json)
  end
  w = JSON.parse(File.read(json))["workloads"].find { _1["workload"] == workload } or abort "#{workload} not measured at #{sha}"
  File.open(log, "a") { _1.puts [workload, sha, w["ir_per_op"].round(1), w["objects_per_op"], git.("log", "-1", "--format=%s", sha)].join("\t") }
  w["ir_per_op"]
end

g, b = measure.(good), measure.(bad)
puts format("good %s %.0f  bad %s %.0f  (%+.2f%%)", good[0, 10], g, bad[0, 10], b, 100 * (b / g - 1))
list = git.("rev-list", "--first-parent", "--reverse", "#{good}..#{bad}").split # list.last == bad
lo, hi = -1, list.size - 1 # list[lo] (or good) is good, list[hi] is bad
while hi - lo > 1
  mid = (lo + hi) / 2
  ir = measure.(list[mid])
  verdict = (ir - g).abs < (ir - b).abs ? :good : :bad
  puts format("%s %.0f %s  %s", list[mid][0, 10], ir, verdict, git.("log", "-1", "--format=%s", list[mid])[0, 80])
  verdict == :good ? lo = mid : hi = mid
end
first = list[hi]
puts "first bad: #{first[0, 10]} #{git.("log", "-1", "--format=%s", first)}"
puts "parent:    #{(lo >= 0 ? list[lo] : good)[0, 10]}"
