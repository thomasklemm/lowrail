# ruby -Igem/lib options.rb NAME PLANT_REGEX UNCHANGED_DIR... [-- PLANTED_DIR...]
# The gate design options of docs/profile-gate-design.md, each run with the gem's own Lowrail::ProfileCompare
# over every assignment of distinct captures (each DIR holds report.json(.gz)):
#   aa1:     today's gate: base, one A/A report, head (compare BASE HEAD --aa BASE2)
#   aa1-all: the same, an action compared on all objects per request instead of warm
#   k3:      base is three captures: its value their mean, its noise their spread across all six runs
#   k3-all:  k3 with actions on all
# "one compare" is compare BASE HEAD; "CI job" also profiles head again and fails only if HEAD2 exits 1 too.
# A planted head is caught when the comparison exits 1 with a row matching PLANT_REGEX (both, for the CI job).
# For the plant it also prints the row's delta against its floor, and per mode the median line and action floor.
require "json"
require "zlib"
require "lowrail/profile_compare"

name = ARGV.shift
plant = Regexp.new(ARGV.shift)
unchanged, planted = ARGV.join(" ").split(" -- ").map(&:split)
planted ||= []
READ = (unchanged + planted).to_h do |d|
  text = File.exist?("#{d}/report.json") ? File.read("#{d}/report.json") : Zlib::GzipReader.open("#{d}/report.json.gz", &:read)
  [d, JSON.parse(text)]
end

def with_all(report)
  copy = Marshal.load(Marshal.dump(report))
  rows = [copy["actions"], *Lowrail::ProfileCompare::KINDS.drop(1).map { copy.dig("outside_requests", _1, "actions") }].compact
  rows.flatten.each { |row| row["warm"] = row["all"] }
  copy
end

# Rows of several captures as one: every vector the concatenation of theirs; a line a capture lacks reads 0 there,
# an action it lacks is left out of the merged report.
def merged(reports)
  copy = Marshal.load(Marshal.dump(reports.first))
  zero = [0.0] * reports.first["meta"]["runs"]
  merge = lambda do |lists, key, line|
    names = lists.flat_map { |l| l.map { _1[key] } }.uniq
    names.filter_map do |n|
      rows = lists.map { |l| l.find { _1[key] == n } }
      next if !line && rows.include?(nil)
      (rows.compact.first.dup).merge("warm" => rows.flat_map { _1 ? _1["warm"] : zero }, "all" => (rows.flat_map { _1 && _1["all"].is_a?(Array) ? _1["all"] : zero } unless line))
    end
  end
  copy["ranked"] = merge.(reports.map { _1["ranked"] }, "site", true)
  copy["actions"] = merge.(reports.map { _1["actions"] }, "name", false)
  Lowrail::ProfileCompare::KINDS.drop(1).each do |k|
    copy["outside_requests"][k]["ranked"] = merge.(reports.map { _1.dig("outside_requests", k, "ranked") }, "site", true)
    copy["outside_requests"][k]["actions"] = merge.(reports.map { _1.dig("outside_requests", k, "actions") }, "name", false)
  end
  copy
end

VALID = Hash.new do |h, d|
  problems = Lowrail::ProfileCompare.allocate.report_problems(d, READ.fetch(d))
  raise "#{d}: #{problems.join("; ")}" unless problems.empty?
  h[d] = true
end
PREP = Hash.new do |h, (dirs, all)|
  reports = dirs.map { |d| VALID[d] && READ.fetch(d) }
  report = reports.size > 1 ? merged(reports) : reports.first
  h[[dirs, all]] = all ? with_all(report) : report
end

# compare with every report already checked: base (one capture or several merged), the A/A report and head.
class Gate < Lowrail::ProfileCompare
  def initialize(base, aa, head)
    @aa_given, @min, @top, @not_compared = true, 1.0, 20, []
    @base, @aa, @head = base, aa, head
  end

  def problems = []
end

memo = {}
gate = lambda do |bases, head, all|
  memo[[bases, head, all]] ||= begin
    base = bases.size == 2 ? PREP[[bases.first(1), all]] : PREP[[bases, all]]
    aa = bases.size == 2 ? PREP[[bases.last(1), all]] : base
    g = Gate.new(base, aa, PREP[[[head], all]])
    [g.regressions.any? ? 1 : 0, g.regressions.map(&:name), nil, g]
  end
end
pct = ->(n, d) { d.zero? ? "–" : format("%d of %d (%.2f%%)", n, d, 100.0 * n / d) }
median = ->(list) { list.empty? ? nil : list.sort[list.size / 2] }

puts "## #{name}"
puts "unchanged: #{unchanged.size}, planted: #{planted.size}"
{ "aa1" => [2, false], "aa1-all" => [2, true], "k3" => [3, false], "k3-all" => [3, true] }.each do |mode, (k, all)|
  next if unchanged.size < k + 1
  base_sets = k == 2 ? unchanged.permutation(2).to_a : unchanged.combination(3).to_a
  # Large sets: a fixed sample of 300 base assignments (heads stay exhaustive).
  sampled = base_sets.size > 300
  base_sets = base_sets.sample(300, random: Random.new(1)) if sampled
  one = base_sets.flat_map { |b| (unchanged - b).map { |h| gate.(b, h, all) } }
  job = base_sets.flat_map do |b|
    (unchanged - b).permutation(2).map { |h, h2| (first = gate.(b, h, all))[0] == 1 ? gate.(b, h2, all) : first }
  end
  rows = one.select { _1[0] == 1 }.flat_map { _1[1] }.tally.sort_by { -_2 }.first(3).map { "#{_1.split("/").last(2).join("/")} #{_2}" }
  line = "#{mode}#{" (300 sampled base assignments)" if sampled}: false alarms, one compare #{pct.(one.count { _1[0] == 1 }, one.size)}"
  line << ", CI job #{pct.(job.count { _1[0] == 1 }, job.size)}" unless job.empty?
  line << "; rows: #{rows.join(", ")}" unless rows.empty?
  unless planted.empty?
    hit = ->(r) { r[0] == 1 && r[1].any? { _1.match?(plant) } }
    caught = base_sets.flat_map { |b| planted.map { |p| hit.(gate.(b, p, all)) } }
    pairs = base_sets.flat_map { |b| planted.permutation(2).map { |p, p2| hit.(gate.(b, p, all)) && hit.(gate.(b, p2, all)) } }
    line << "; plant caught, one compare #{pct.(caught.count(true), caught.size)}"
    line << ", CI job #{pct.(pairs.count(true), pairs.size)}" unless pairs.empty?
    sample = gate.(base_sets.first, planted.first, all)[3]
    rows = sample.changes.select { _1.name.match?(plant) }.sort_by { -_1.delta }.first(2)
    line << "; plant rows (#{base_sets.first.map { File.basename(_1) }.join("+")} vs #{File.basename(planted.first)}): " +
      rows.map { "#{_1.name.split("/").last(2).join("/")} +#{_1.delta.round(1)} floor #{_1.threshold(1.0).round(1)} of #{_1.base.round(0)}" }.join(", ")
  end
  sample = gate.(base_sets.first, (unchanged - base_sets.first).first, all)[3]
  floors = sample.changes.group_by(&:what).transform_values { |cs| cs.map { _1.threshold(1.0) } }
  rel = sample.changes.select { _1.what == "action" && _1.base > 0 }.map { _1.threshold(1.0) / _1.base }
  line << "; median floor: line #{median.(floors["line"] || [])&.round(2)}, action #{median.(floors["action"] || [])&.round(1)} " \
    "(#{((median.(rel) || 0) * 100).round(1)}% of the action), #{sample.not_compared.size} actions not compared"
  puts line
end
