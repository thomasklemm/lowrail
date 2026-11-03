# Rank --zjit-stats-iseq output (docs/upstream/zjit-iseq-leads.md) across apps.
#   ruby bench/upstream/zjit_iseq_rank.rb [--top N] DIR_OR_JSON...
# Each JSON is {app:, ops:, stats: {"iseq:<counter>:<label>@<path>:<line>" => n, ...}}
# (script/jit-parity-census stats-one, or bench/upstream/zjit_iseq_harness.rb).
# Ranks (counter, ISEQ) pairs by apps reached, then by count per op (an op is one request/job/mailer
# for the census apps, one iteration for ruby-bench); also
# reports per-app concentration and the global-vs-per-ISEQ sum check.
require "json"

top = 25
args = ARGV.dup
if (i = args.index("--top")) then top = Integer(args[i + 1]); args.slice!(i, 2) end
files = args.flat_map { File.directory?(_1) ? Dir["#{_1}/*.json"] : [_1] }.sort
LEAD = /\A(send_fallback_|exit_|getivar_fallback_|setivar_fallback_|definedivar_fallback_)/
# send_fallback_* reasons that only break down another send_fallback_* counter.
DETAIL = /\Asend_fallback_(send_without_block|send|invokesuper|invokeblock|send_forward)_?\z/

# Drop install prefixes and gem versions so one Rails method keys the same in every app.
def short(loc) = loc.sub(%r{@/\S*/gems/4\.1\.0\+\d+/(?:bundler/)?gems/}, "@").sub(%r{@/\S*/lib/ruby/4\.1\.0\+\d+/}, "@")
  .sub(%r{@([a-z_]+(?:-[a-z_]+)*)-[0-9a-f][0-9a-f.]*/}, '@\\1/').sub(%r{@rails/(\w+)/}, '@\\1/')
  .sub(%r{@/home/user/workspace/repo/\.corpus/[^/]+/}, "@app/")

pairs = Hash.new { |h, k| h[k] = {} } # [counter, iseq] => {app => per_op}
apps = {}
mismatch = []
files.each do |f|
  d = JSON.parse(File.read(f))
  app, ops, stats = d.fetch("app"), d.fetch("ops").to_f, d.fetch("stats")
  apps[app] = Hash.new(0)
  sums = Hash.new(0)
  stats.each do |k, v|
    next unless k.start_with?("iseq:")
    counter, iseq = k.delete_prefix("iseq:").split(":", 2)
    sums[counter] += v
    next unless counter.match?(LEAD) && !counter.match?(DETAIL)
    pairs[[counter, short(iseq)]][app] = v / ops
    apps[app][counter[/\A[a-z]+_[a-z]+/]] += v / ops
  end
  sums.each { |c, s| mismatch << [app, c, s, stats[c].to_i] if s != stats[c].to_i }
end

puts "apps: #{apps.size} (#{apps.keys.join(", ")})"
puts "per-ISEQ sums that differ from the global counter: #{mismatch.size}"
mismatch.first(10).each { puts "  #{_1.inspect}" }
puts
puts "| # | counter | ISEQ | apps | mean/op | max/op (app) |"
puts "|---|---|---|---|---|---|"
pairs.sort_by { |(_, _), per| [-per.size, -per.values.sum] }.first(top).each_with_index do |((c, iseq), per), i|
  app, m = per.max_by { _2 }
  puts "| #{i + 1} | `#{c}` | `#{iseq}` | #{per.size} | #{(per.values.sum / per.size).round(1)} | #{m.round(1)} (#{app}) |"
end
puts
puts "Top by summed cost (any breadth):"
puts "| # | counter | ISEQ | apps | mean/op over all apps |"
puts "|---|---|---|---|---|"
pairs.sort_by { |_, per| -per.values.sum }.first(top).each_with_index do |((c, iseq), per), i|
  puts "| #{i + 1} | `#{c}` | `#{iseq}` | #{per.size} | #{(per.values.sum / apps.size).round(1)} |"
end
puts
puts "Reasons by apps reached (counter summed over ISEQs):"
by_c = Hash.new { |h, k| h[k] = Hash.new(0) }
pairs.each { |(c, _), per| per.each { |a, v| by_c[c][a] += v } }
by_c.sort_by { |_, per| [-per.size, -per.values.sum] }.first(top).each do |c, per|
  puts "  #{c.ljust(55)} apps #{per.size.to_s.rjust(2)}  mean/op over all apps #{(per.values.sum / apps.size).round(1)}"
end
