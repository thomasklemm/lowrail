# ruby noise_gate.rb [SET...] > ../results.md
# (2026-11-26 calibration: a copy of ../../2026-11-25-gate-0.2/scripts/noise_gate.rb whose SETS are this round's
# captures, plus VARIANTS=REGEX to print only the variants whose label matches; the rules are unchanged.)
#
# Candidate 0.2 gates for lowrail-profile compare (docs/profile-0.2-design.md), evaluated over every assignment of
# distinct unchanged captures of one app to base (k captures) and head, and for the CI job to head and head2.
# Self-contained: it reads report.json(.gz) warm vectors and does not load the gem, so the gem may change under it.
# The variant "aa1" is 0.1's rule (base, one A/A capture, head) and reproduces the aa1 lines of
# ../2026-11-25-t3/options-*.txt; the others are the candidates.
#
# A row is a line (warm objects per request at one site) or an action (warm objects per request of one controller
# action, job, mail or Cable action), per kind of window that every run of every capture has. A line a capture lacks
# is a measured zero; an action that is missing or has no warm value in any compared capture is not compared.
#
# Per row, with base captures b_1..b_k (2 runs each), head h:
#   B = mean of the base runs, H = head's mean, delta = H - B, hs = head's own run spread,
#   floor F = 1 object for a line; max(20, share * max(B, H)) for an action (share 0.1% unless the variant says).
#   aa1       B = b_1's mean only; T = max(2 * max(range of b_1 and b_2's runs, hs), F)            (0.1, k = 2)
#   range-c   T = max(c * max(range of all 2k base runs, hs), F)
#   env       T = (highest base run - B) + max(hs, F): head must clear every base run by the floor
#   pred      T = max(t(k-1, 99%) * sd(capture means) * sqrt(1 + 1/k), F): a one-sided prediction interval
#   rank      T = max(highest base capture mean - B, F): head above every base capture, and by the floor
# A row is flagged when delta > T. "r1" variants use only each capture's first run (a --runs 1 capture).
# "self-check" variants first compare each base capture against the other k - 1 with the same rule; when any of
# those flags, the job declines to gate (Declined column) and the other columns count only the base sets it gates.
#
# Measures: false alarms of one compare (an unchanged head with any flagged row); of the CI job, which profiles head
# again when the first compare flags and fails only if the second flags too ("any": any row; "same": a row flagged
# by both; "merged": a row the first compare flagged is still flagged when head and head2 are compared as one head
# of four runs); plant detection (a planted head with a flagged row matching the plant pattern; for the CI job, the
# merged rule on both planted captures); and the smallest detectable regression: per compared action, the added objects per request
# that an unchanged head would need to be flagged in 95% of assignments (d95), reported as the median and 90th
# percentile over actions, in objects and as a share of the action.
require "json"
require "zlib"

UP = File.expand_path("../../..", __dir__) # bench/upstream
PR = "#{UP}/profile_release"
SW = "#{UP}/oss_profile_sweep_1"
HERE = File.expand_path("..", __dir__)
KINDS = %w[request job mail cable].freeze
T99 = { 1 => 31.821, 2 => 6.965, 3 => 4.541, 4 => 3.747 }.freeze
LIMIT = 120 # base sets sampled per configuration when there are more (heads stay exhaustive)

CAP = "#{HERE}/captures"
serial = ->(app) { (1..8).map { "#{CAP}/#{app}/s#{_1}" } }
planted = ->(app) { %w[planted planted2].map { "#{CAP}/#{app}/#{_1}" } }
SETS = {
  # Forem: the first s3 and s6 are not evidence (README: a flaky example, then EMLINK); s6 was rerun and s9 added.
  "forem" => ["Forem, rspec spec/requests, PARALLEL_WORKERS=1, 8 + 2 planted", %w[s1 s2 s4 s5 s6 s7 s8 s9].map { "#{CAP}/forem/#{_1}" }, planted.("forem"),
    /StoriesController#index|output_safety|erb\/util/],
  "osm" => ["openstreetmap-website, PARALLEL_WORKERS=1, 8 + 2 planted", serial.("osm"), planted.("osm"), /NotesController#index/],
  "campfire" => ["Campfire, PARALLEL_WORKERS=1, 8 + 2 planted", serial.("campfire"), planted.("campfire"),
    /output_safety|erb\/util|RoomsController#show/],
  "hackatime" => ["Hackatime, PARALLEL_WORKERS=1, 8 + 2 planted", serial.("hackatime"), planted.("hackatime"),
    /LeaderboardsController#index|output_safety|erb\/util/]
}.freeze

def read(dir)
  path = Dir["#{dir}/report.json{,.gz}"].first or abort "#{dir}: no report.json"
  r = JSON.parse(path.end_with?(".gz") ? Zlib::GzipReader.open(path, &:read) : File.read(path))
  m = r["meta"]
  ok = m["format"] == 2 && m["runs"] == 2 && m["exit"] == [0, 0] && m["dropped"] == [0, 0] &&
    r["summary"].all? { |s| KINDS.all? { s["windows"][_1] == s["completed"][_1] } }
  abort "#{dir}: not valid evidence" unless ok
  rows = {}
  KINDS.each do |k|
    src = k == "request" ? r : r.dig("outside_requests", k)
    next unless src
    src["ranked"].each { rows[[k, "line", _1["site"]]] = _1["warm"].map(&:to_f) }
    src["actions"].each do |a|
      w = a["warm"]
      rows[[k, "action", a["name"] || "(no name)"]] = w && !w.empty? && !w.include?(nil) ? w.map(&:to_f) : nil
    end
  end
  { procs: r["summary"].map { _1["processes"] }.max, kinds: KINDS.select { |k| r["summary"].all? { _1["windows"][k].to_i > 0 } }, rows: }
end

Row = Struct.new(:key, :line, :vals, :mean, :lo, :hi, :inert)

def rows_of(caps, runs)
  kinds = caps.map { _1[:kinds] }.reduce(:&)
  keys = caps.flat_map { _1[:rows].keys }.uniq.select { kinds.include?(_1[0]) }
  keys.map do |key|
    line = key[1] == "line"
    vals = caps.map do |c|
      v = c[:rows].key?(key) ? c[:rows][key] : (line ? [0.0, 0.0] : nil)
      v && (runs == :first ? v.first(1) : v)
    end
    mean = vals.map { _1 && _1.sum / _1.size }
    Row.new(key, line, vals, mean, vals.map { _1&.min }, vals.map { _1&.max }, !vals.include?(nil) && vals.flatten.uniq.size == 1)
  end
end

# [flagged?, d_min] for one row: d_min is how much more head needs to be flagged (0 when it already is).
def judge(row, v, bs, h)
  heads = Array(h)
  return nil if !row.line && (bs + heads).any? { row.vals[_1].nil? }
  k = bs.size
  hm = heads.sum { row.mean[_1] } / heads.size
  hs = heads.map { row.hi[_1] }.max - heads.map { row.lo[_1] }.min
  b = v[:name] == "aa1" ? row.mean[bs[0]] : bs.sum { row.mean[_1] } / k
  share = v[:share] || 0.001
  floor = row.line ? 1.0 : [20.0, share * [b, hm].max].max
  hi, lo = bs.map { row.hi[_1] }.max, bs.map { row.lo[_1] }.min
  t = case v[:name]
  when "aa1" then [2 * [hi - lo, hs].max, floor].max
  when "range" then [v[:c] * [hi - lo, hs].max, floor].max
  when "env" then (hi - b) + [hs, floor].max
  when "pred"
    m = bs.map { row.mean[_1] }
    sd = Math.sqrt(m.sum { (_1 - b)**2 } / (k - 1))
    [T99.fetch(k - 1) * sd * Math.sqrt(1 + 1.0 / k), floor].max
  when "rank" then [bs.map { row.mean[_1] }.max - b, floor].max
  end
  delta = hm - b
  [delta > t, [t - delta, 0.0].max, b]
end

def variants
  list = [{ name: "aa1", k: 2, label: "aa1 (0.1 rule)" }]
  (2..5).each do |k|
    list << { name: "range", c: 2, k:, label: "range-2 k#{k}" }
    list << { name: "range", c: 3, k:, label: "range-3 k#{k}" }
    list << { name: "range", c: 2, k:, share: 0.005, label: "range-2 k#{k} share 0.5%" }
    list << { name: "env", k:, label: "env k#{k}" }
    list << { name: "env", k:, share: 0.005, label: "env k#{k} share 0.5%" }
    list << { name: "pred", k:, label: "pred99 k#{k}" }
    list << { name: "rank", k:, label: "rank k#{k}" }
    list << { name: "range", c: 2, k:, runs: :first, label: "range-2 k#{k} r1" }
    list << { name: "env", k:, runs: :first, label: "env k#{k} r1" }
    next if k < 3
    list << { name: "range", c: 2, k:, self: true, label: "range-2 k#{k} self-check" }
    list << { name: "env", k:, self: true, label: "env k#{k} self-check" }
  end
  list
end

pct = ->(n, d) { d.zero? ? "–" : format("%.2f%% (%d/%d)", 100.0 * n / d, n, d) }
quant = ->(list, q) { list.empty? ? nil : list.sort[[(q * list.size).ceil - 1, 0].max] }
short = ->(key) { "#{key[1] == "line" ? key[2].split("/").last(2).join("/") : key[2]}" }

sets = ARGV.empty? ? SETS.keys : ARGV
summary = []
puts "# Candidate 0.2 compare gates, evaluated on the receipts (output of scripts/noise_gate.rb)\n\n"
puts "Columns: false alarms of one compare, of the CI job (head profiled again on a flag; *any* row or the *same* row " \
  "flagged twice), plant caught (one compare / CI job), and the smallest regression an action needs to be flagged in 95% " \
  "of assignments (d95: median and 90th percentile over compared actions, objects per request and share of the action). " \
  "Base sets are all assignments, or #{LIMIT} sampled (seed 1) where there are more.\n\n"
sets.each do |set|
  title, unchanged, planted, plant = SETS.fetch(set)
  caps = (unchanged + planted).map { read(_1) }
  n = unchanged.size
  u = (0...n).to_a
  pl = (n...(n + planted.size)).to_a
  rows = { both: rows_of(caps, :both), first: rows_of(caps, :first) }
  puts "## #{set}: #{title}\n\n"
  puts "Processes per capture: #{caps.map { _1[:procs] }.uniq.join(", ")}. Kinds compared: #{caps.map { _1[:kinds] }.reduce(:&).join(", ")}. " \
    "Rows: #{rows[:both].size}, of which #{rows[:both].count(&:inert)} are identical in every run of every capture.\n\n"
  puts "| Variant | Declined | One compare | CI job (any) | CI job (same row) | CI job (merged) | Plant: one / CI | Action d95 median | Action d95 p90 | Rows flagged most |"
  puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
  variants.each do |v|
    next if ENV["VARIANTS"] && !v[:label].match?(Regexp.new(ENV["VARIANTS"]))
    k = v[:k]
    next if n < k + (v[:self] ? 0 : 1)
    live = rows[v[:runs] || :both].reject(&:inert)
    inert_actions = rows[v[:runs] || :both].select { _1.inert && !_1.line }
    bases = v[:name] == "aa1" ? u.permutation(2).to_a : u.combination(k).to_a
    bases = bases.sample(LIMIT, random: Random.new(1)) if bases.size > LIMIT
    memo = {}
    eval = lambda do |bs, h|
      memo[[bs, h]] ||= begin
        flagged = []
        dmins = {}
        live.each do |row|
          r = judge(row, v, bs, h) or next
          flagged << row.key if r[0]
          dmins[row.key] = [r[1], r[2]] unless row.line
        end
        [flagged, dmins]
      end
    end
    one = 0; one_n = 0; any = 0; same = 0; merged = 0; job_n = 0; tally = Hash.new(0)
    per_action = Hash.new { |hh, kk| hh[kk] = [] }
    all_bases = bases.size
    bases = bases.reject { |bs| bs.any? { |b| !eval.(bs - [b], b)[0].empty? } } if v[:self]
    declined = v[:self] ? pct.(all_bases - bases.size, all_bases) : "–"
    bases.each do |bs|
      heads = u - bs
      heads.each do |h|
        f, d = eval.(bs, h)
        one_n += 1
        one += 1 unless f.empty?
        f.each { tally[_1] += 1 }
        d.each { |key, (dm, b)| per_action[key] << [dm, b] }
      end
      heads.permutation(2).each do |h, h2|
        job_n += 1
        f1 = eval.(bs, h)[0]
        next if f1.empty?
        f2 = eval.(bs, h2)[0]
        any += 1 unless f2.empty?
        same += 1 unless (f1 & f2).empty?
        merged += 1 unless (f1 & eval.(bs, [h, h2].sort)[0]).empty?
      end
    end
    plant_cell = if pl.empty?
      "–"
    else
      hit = ->(bs, p) { eval.(bs, p)[0].any? { short.(_1).match?(plant) || _1[2].match?(plant) } }
      c1 = bases.sum { |bs| pl.count { hit.(bs, _1) } }
      pairs = bases.flat_map { |bs| pl.permutation(2).map { |p, p2| hit.(bs, p) && hit.(bs, [p, p2].sort) } }
      "#{pct.(c1, bases.size * pl.size)} / #{pairs.empty? ? "–" : pct.(pairs.count(true), pairs.size)}"
    end
    d95 = per_action.values.map { |l| [quant.(l.map(&:first), 0.95), l.sum(&:last) / l.size] }
    # Actions identical everywhere still need the floor.
    d95 += inert_actions.map { |row| b = row.mean.first; [[20.0, (v[:share] || 0.001) * b].max, b] }
    abs = d95.map(&:first)
    rel = d95.select { _1[1] > 0 }.map { _1[0] / _1[1] }
    fmt = ->(q) { a, r = quant.(abs, q), quant.(rel, q); a && one_n > 0 ? format("%.0f (%.2f%%)", a, 100 * r) : "–" }
    top = tally.sort_by { -_2 }.first(2).map { "#{short.(_1)} #{_2}" }.join(", ")
    puts "| #{v[:label]} | #{declined} | #{pct.(one, one_n)} | #{pct.(any, job_n)} | #{pct.(same, job_n)} | #{pct.(merged, job_n)} | #{plant_cell} | #{fmt.(0.5)} | #{fmt.(0.9)} | #{top} |"
    summary << [set, v[:label], one, one_n, any, job_n, merged, plant_cell, fmt.(0.5)]
  end
  puts
end

# Across the one-process sets: the worst false-alarm rate per variant.
serial = summary.reject { _1[0].end_with?("-parallel") }
unless serial.empty?
  puts "## Across the one-process sets\n\nWorst set per variant among the sets with enough captures for it (k + 1 for one compare, k + 2 for the CI job).\n\n" \
    "| Variant | Sets measured | Worst one compare | Worst CI job (merged) | Sets with a CI false alarm |\n| --- | --- | ---: | ---: | --- |"
  serial.group_by { _1[1] }.each do |label, list|
    worst1 = list.max_by { _1[3].zero? ? 0 : _1[2].fdiv(_1[3]) }
    worstj = list.max_by { _1[5].zero? ? 0 : _1[6].fdiv(_1[5]) }
    bad = list.select { _1[6] > 0 }.map { _1[0] }
    puts "| #{label} | #{list.map { _1[0] }.join(", ")} | #{worst1[0]} #{pct.(worst1[2], worst1[3])} | #{worstj[0]} #{pct.(worstj[6], worstj[5])} | #{bad.join(", ")} |"
  end
end
