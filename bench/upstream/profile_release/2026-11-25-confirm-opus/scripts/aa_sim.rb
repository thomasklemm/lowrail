# ruby -Igem/lib aa_sim.rb UNCHANGED_DIR... -- PLANTED_DIR...
# Each DIR holds report.json(.gz). With compare's own floor (ProfileCompare: line floor = max(spread of all
# base-side runs, spread of head runs, --min); action floor = max(2 × that, 0.1%, 20 × --min)), how often does a
# head of unchanged code fail, by strategy, over every assignment of distinct unchanged captures:
#   aa1:  base + 1 A/A capture, one head (the default, 6 suite runs)
#   aa2:  base + 2 A/A captures, one head (8 runs)
#   rerun: aa1, and when it fails, a second head; a row fails only if it fails with both heads'
#          runs as head's (spread of both, mean of both) (6 runs, 8 when anything is flagged)
# and does a planted head still fail on the planted line (output_safety.rb:228) under each?
require "json"
require "zlib"
require "lowrail/profile_compare"

dirs = ARGV.join(" ").split(" -- ").map(&:split)
unchanged, planted = dirs[0], dirs[1] || []
load_report = ->(d) do
  f = File.exist?("#{d}/report.json") ? File.read("#{d}/report.json") : Zlib::GzipReader.open("#{d}/report.json.gz", &:read)
  JSON.parse(f)
end
reports = (unchanged + planted).to_h { [_1, load_report.(_1)] }
# Private helpers of ProfileCompare (the receipts' own margin.rb uses them the same way).
pc = Lowrail::ProfileCompare.allocate
lines = ->(r) { pc.send(:lines, r, "request") }
acts = ->(r) { pc.send(:actions, r, "request").select { |_, w| w && !w.empty? && !w.include?(nil) } }
spread = ->(v) { v.size > 1 ? v.max - v.min : 0.0 }
mean = ->(v) { v.sum / v.size }
MIN = 1.0
# rows that fail: base, aas (list), heads (list of reports; their runs pooled as head's)
fails = lambda do |base, aas, heads|
  out = []
  [[lines, :line], [acts, :action]].each do |get, what|
    b = get.(base); as = aas.map { get.(_1) }; hs = heads.map { get.(_1) }
    names = what == :line ? (b.keys | hs.flat_map(&:keys)) : b.keys.select { |n| hs.all? { _1[n] } && as.all? { _1[n] } }
    zero = [0.0] * base["meta"]["runs"]
    names.each do |n|
      bv = b[n] || zero
      side = bv + as.flat_map { _1[n] || zero }
      hv = hs.flat_map { _1[n] || zero }
      noise = [spread.(side), spread.(hv)].max
      floor = what == :line ? [noise, MIN].max : [2 * noise, 0.001 * [mean.(bv), mean.(hv)].max, 20 * MIN].max
      d = mean.(hv) - mean.(bv)
      out << [what, n, d.round(2), floor.round(2)] if d > floor
    end
  end
  out
end

def tally(label, results)
  failing = results.count { !_1.empty? }
  rows = results.flatten(1).group_by { _1[1] }.transform_values(&:size).sort_by { -_2 }.first(5)
  puts format("%-6s %4d of %4d unchanged heads fail (%.1f%%); rows: %s", label, failing, results.size, 100.0 * failing / results.size, rows.inspect)
end

u = unchanged
aa1 = u.permutation(3).map { |b, a, h| fails.(reports[b], [reports[a]], [reports[h]]) }
aa2 = u.permutation(4).map { |b, a, a2, h| fails.(reports[b], [reports[a], reports[a2]], [reports[h]]) }
rerun = u.permutation(4).map do |b, a, h, h2|
  first = fails.(reports[b], [reports[a]], [reports[h]])
  first.empty? ? first : fails.(reports[b], [reports[a]], [reports[h], reports[h2]])
end
puts "unchanged captures: #{u.size}"
tally("aa1", aa1); tally("aa2", aa2); tally("rerun", rerun)

uri = "RUBY/uri/common.rb:394"
vals = u.map { lines.(reports[_1])[uri] }.compact
puts "#{uri} per capture (warm per run): #{vals.map { |v| v.map { _1.round(2) } }.inspect}"

planted.each do |p|
  # A planted capture's second head is the planted code again: in the rerun the second head is planted too,
  # so pair planted heads with each other when there are two.
  others = planted - [p]
  ok = ->(rows) { rows.any? { _1[1].include?("output_safety.rb:228") } }
  r1 = u.permutation(2).map { |b, a| fails.(reports[b], [reports[a]], [reports[p]]) }
  r2 = u.permutation(3).map { |b, a, a2| fails.(reports[b], [reports[a], reports[a2]], [reports[p]]) }
  rr = others.empty? ? [] : u.permutation(2).flat_map { |b, a| others.map { |p2| fails.(reports[b], [reports[a]], [reports[p], reports[p2]]) } }
  puts "planted #{p}: aa1 catches #{r1.count(&ok)}/#{r1.size}, aa2 #{r2.count(&ok)}/#{r2.size}, rerun #{rr.count(&ok)}/#{rr.size}; " \
    "other rows flagged in aa1: #{r1.count { |rows| rows.any? { !_1[1].include?("output_safety.rb:228") } }}/#{r1.size}"
end

# confirm: shell-only CI recipe; on exit 1 capture head again and fail only if base vs head2 also fails.
confirm = u.permutation(4).map do |b, a, h, h2|
  first = fails.(reports[b], [reports[a]], [reports[h]])
  first.empty? ? first : fails.(reports[b], [reports[a]], [reports[h2]])
end
tally("confirm", confirm)
if (pat = ENV["PLANT_LINE"])
  planted.each do |p|
    r1 = u.permutation(2).map { |b, a| fails.(reports[b], [reports[a]], [reports[p]]) }
    puts "#{p}: rows matching #{pat} in #{r1.count { |rows| rows.any? { _1[1].match?(pat) } }}/#{r1.size}; " \
      "rows not matching in #{r1.count { |rows| rows.any? { !_1[1].match?(pat) } }}/#{r1.size}"
  end
end
