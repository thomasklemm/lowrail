# ruby -Igem/lib gate.rb PLANT_REGEX UNCHANGED_DIR... -- PLANTED_DIR...
# IGNORE=REGEX: leave regressions whose name matches out (analysis only: which alarms other rows explain).
# compare's gate as rc1 had it (exit 1 when Lowrail::ProfileCompare lists a regression; 0.1 only reports it) over every assignment of distinct
# captures to base, A/A, head and head2; each DIR holds report.json(.gz).
#   default:  compare BASE HEAD --aa BASE2 exits 1
#   confirm:  the README's CI job: on exit 1, profile head again (HEAD2) and fail only if
#             compare BASE HEAD2 --aa BASE2 exits 1 too
# An unchanged head that fails is a false alarm; a planted head is caught when it fails with a row matching
# PLANT_REGEX (in both comparisons for confirm). Each with a line's floor as in 0.1.0.rc1 before this change
# (its noise, "rc1") and as now (twice it, "now"); an action's floor is the same in both.
require "json"
require "zlib"
require "lowrail/profile_compare"

plant = Regexp.new(ARGV.shift)
unchanged, planted = ARGV.join(" ").split(" -- ").map(&:split)
planted ||= []
REPORTS = (unchanged + planted).to_h do |d|
  text = File.exist?("#{d}/report.json") ? File.read("#{d}/report.json") : Zlib::GzipReader.open("#{d}/report.json.gz", &:read)
  # Format 2 reports: every capture of one app has the same keys, so read as format 3.
  [d, JSON.parse(text).tap { |r| r["meta"]["format"] = Lowrail::ProfileReport::FORMAT }]
end

$rc1 = false
Lowrail::ProfileCompare::Change.prepend(Module.new do
  def threshold(min) = $rc1 && what == "line" ? [noise, min].max : super
end)

# The parallel cohorts predate compare's refusal of several processes (abf515d3): they replay without that check.
PARALLEL = / ran in \d+ processes: parallel test workers/

class Gate < Lowrail::ProfileCompare
  def problems = super.grep_v(PARALLEL)

  def initialize(base, head, aa)
    @aa_given = true
    @base, @head, @aa = REPORTS.fetch(base), REPORTS.fetch(head), REPORTS.fetch(aa)
    @min, @top, @not_compared = 1.0, 20, []
  end
end

memo = {}
gate = lambda do |b, a, h|
  memo[[$rc1, b, a, h]] ||= begin
    g = Gate.new(b, h, a)
    raise "#{b} #{a} #{h}: #{g.problems.join("; ")}" unless g.valid?
    regs = g.regressions.map(&:name).reject { ENV["IGNORE"] && _1.match?(Regexp.new(ENV["IGNORE"])) }
    [regs.any? ? 1 : 0, regs]
  end
end
pct = ->(n, d) { d.zero? ? "-" : format("%d of %d (%.2f%%)", n, d, 100.0 * n / d) }
short = ->(name) { name.split("/").last(2).join("/") }
tally = ->(lists) { lists.flatten.tally.sort_by { -_2 }.first(4).map { "#{short.(_1)} #{_2}" }.join(", ") }
label = ->(d) { d.split("/").last(2).join("/") }

puts "unchanged: #{unchanged.map(&label).join(" ")}"
puts "planted: #{planted.map(&label).join(" ")}" unless planted.empty?
[false].each do |rc1|
  $rc1 = rc1
  name = rc1 ? "rc1 (line floor = noise)" : "now (line floor = 2 x noise)"
  default = unchanged.permutation(3).map { |b, a, h| gate.(b, a, h) }
  confirm = unchanged.permutation(4).map do |b, a, h, h2|
    first = gate.(b, a, h)
    first[0] == 1 ? gate.(b, a, h2) : first
  end
  puts "#{name}:"
  puts "  false alarms, default: #{pct.(default.count { _1[0] == 1 }, default.size)}; rows: #{tally.(default.select { _1[0] == 1 }.map(&:last))}"
  puts "  false alarms, confirm: #{pct.(confirm.count { _1[0] == 1 }, confirm.size)}; rows: #{tally.(confirm.select { _1[0] == 1 }.map(&:last))}"
  next if planted.empty?
  caught = ->(r) { r[0] == 1 && r[1].any? { _1.match?(plant) } }
  # The planted action's own row grows too; another line is what the plant did not touch.
  other = ->(r) { r[0] == 1 && r[1].any? { !_1.include?("#") && !_1.match?(plant) } }
  d = planted.flat_map { |p| unchanged.permutation(2).map { |b, a| gate.(b, a, p) } }
  puts "  plant caught, default: #{pct.(d.count(&caught), d.size)}; with an unrelated line too: #{d.count(&other)}"
  if planted.size > 1
    c = planted.permutation(2).flat_map { |p, p2| unchanged.permutation(2).map { |b, a| [gate.(b, a, p), gate.(b, a, p2)] } }
    puts "  plant caught, confirm: #{pct.(c.count { |x, y| caught.(x) && caught.(y) }, c.size)}"
  else
    puts "  plant caught, confirm: no second planted capture"
  end
end
