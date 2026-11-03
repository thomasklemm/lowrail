# frozen_string_literal: true

# Rails main watch: compares two census A/A pairs (base: the last recorded
# Rails main, head: current main) per workload and per allocation site,
# against a noise floor. See docs/upstream/rails-main-watch/README.md.
#
# A pair is one Rails commit measured twice (the A/A pair), trimmed:
#   { "rails" => SHA, "ruby" => ..., "runs" => [RUN, RUN] }
#   RUN = { MODE => { APP => { WORKLOAD => { "kind", "gc", "traced", "sql", "sites" } } } }
# gc is the median GC-enabled objects per operation (the census value),
# traced the GC-disabled objects per traced operation, sites FILE:LINE =>
# objects per traced operation summed over classes (every Rails line, other
# lines from 0.5). RAILS/ paths are rails/rails repository paths.
require "json"
require "open3"
require "zlib"

module CensusWatch
  REACH = 0.5

  module_function

  def median(a) = a.sort[a.size / 2]

  def trim(run)
    run["workloads"].to_h do |w|
      sites = Hash.new(0.0)
      w["sites"].each { |s| sites["#{s["file"]}:#{s["line"]}"] += s["objects_per_op"] }
      sites = sites.select { |k, v| k.start_with?("RAILS/") || v >= REACH }.transform_values { _1.round(2) }
      [w["workload"], { "kind" => w["kind"], "gc" => median(w["gc_enabled_objects_per_op"]),
        "traced" => (w["traced_gc_objects"].fdiv(w["ops"] || 10)).round(1), "sql" => w["sql"], "sites" => sites.sort.to_h }]
    end
  end

  def write_receipts(path, set) = Zlib::GzipWriter.open(path) { _1.write(JSON.pretty_generate(set) + "\n") }

  # What a run commits: every workload's values in all four runs (base, base2,
  # head, head2), every moved workload and line, SQL and control diffs, with
  # their attributions. Full receipts stay under .lowrail/private/census.
  def receipts(b, h, result, attributed, controls)
    { "rails" => { "base" => b["rails"], "head" => h["rails"] }, "ruby" => h["ruby"], "apps" => h["apps"], "modes" => h["modes"],
      "workloads" => cells(b, h).map do |mode, app, name, runs|
        { "mode" => mode, "app" => app, "workload" => name, "kind" => runs[0]["kind"], "gc" => runs.map { _1["gc"] },
          "traced" => runs.map { _1["traced"] }, "sql" => runs.map { _1.dig("sql", "digest") } }
      end,
      "moved_workloads" => result[:workloads], "moved_lines" => result[:sites].map { _1.merge(attribution: attributed[_1[:key]]) },
      "sql" => result[:sql], "sql_unstable" => result[:sql_unstable], "controls" => controls }
  end

  # Git in the watch's rails/rails clone.
  class Repo
    def initialize(dir) = @dir = dir

    def git(*args)
      out, status = Open3.capture2("git", "-C", @dir, *args)
      raise "git #{args.join(" ")} failed" unless status.success?
      out
    end

    def ancestor?(a, b) = system("git", "-C", @dir, "merge-base", "--is-ancestor", a, b)

    # Head commit's line LINE of PATH in BASE's numbering, or nil when the
    # line was added or changed between the two (git diff -U0 hunks).
    def base_line(base, head, path, line)
      @hunks ||= {}
      hunks = @hunks[[base, head, path]] ||= git("diff", "-U0", "--no-color", base, head, "--", path)
        .scan(/^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/).map { |a, b, c, d| [a.to_i, (b || 1).to_i, c.to_i, (d || 1).to_i] }
      offset = 0
      hunks.each do |_, removed, start, added|
        if added.positive?
          return nil if line.between?(start, start + added - 1)
          break if start > line
        elsif start >= line
          break
        end
        offset += removed - added
      end
      line + offset
    end

    def blame(head, path, line) = git("blame", "--porcelain", "-L", "#{line},#{line}", head, "--", path)[/\A\h{40}/]

    def first_parents(base, head) = git("rev-list", "--reverse", "--first-parent", "#{base}..#{head}").split

    # The first-parent commit on main that brought COMMIT in.
    def landed_by(first_parents, commit) = first_parents.find { ancestor?(commit, _1) }

    def subject(sha) = git("log", "-1", "--format=%s", sha).strip
    def short(sha) = sha[0, 10]

    def pr(sha)
      s = subject(sha)
      s[/\AMerge pull request #(\d+)/, 1] || s[/\(#(\d+)\)\z/, 1]
    end

    def parents(sha) = git("rev-list", "--parents", "-n1", sha).split.drop(1)
  end

  # Head site key in base numbering: RAILS/path:LINE, or RAILS/path:+LINE for
  # a line added or changed in the range.
  def to_base(repo, base, head, key)
    return key if base == head || !key.start_with?("RAILS/")
    file, line = key.split(/:(?=\d+\z)/)
    mapped = repo.base_line(base, head, file.delete_prefix("RAILS/"), Integer(line))
    mapped ? "#{file}:#{mapped}" : "#{file}:+#{line}"
  end

  def file_of(key) = key.split(/:(?=\+?\d+\z)/).first

  # Every workload of every mode/app present in all four runs.
  def cells(b, h)
    b["runs"].first.flat_map do |mode, apps|
      apps.flat_map do |app, workloads|
        workloads.keys.filter_map do |name|
          runs = [*b["runs"], *h["runs"]].map { _1.dig(mode, app, name) }
          [mode, app, name, runs] if runs.all?
        end
      end
    end
  end

  # Cross deltas head - base over the four pairs; moved when all four clear the
  # floor in the same direction.
  def moved(bs, hs, floor)
    cross = hs.product(bs).map { |h, x| (h - x).round(1) }
    return nil unless cross.all? { _1 > floor && _1 >= 1.0 } || cross.all? { _1 < -floor && _1 <= -1.0 }
    cross.sort[1, 2].sum / 2.0
  end

  def aa(values) = (values[1] - values[0]).abs.round(1)

  # floors: { "MODE/APP/WORKLOAD" => largest A/A |delta| seen in earlier pairs }.
  def compare(repo, b, h, floors)
    base, head = b.fetch("rails"), h.fetch("rails")
    out = { workloads: [], sites: [], sql: [], sql_unstable: [], aa: Hash.new { |x, k| x[k] = [0, 0, 0, 0, 0] }, floors: {} }
    all = cells(b, h)
    all.each do |mode, app, name, (b1, b2, h1, h2)|
      id = "#{mode}/#{app}/#{name}"
      out[:floors][id] = [aa([b1["gc"], b2["gc"]]), aa([h1["gc"], h2["gc"]]), floors.fetch(id, 0)].max
    end
    modes = b["runs"].first.keys
    all.each do |mode, app, name, (b1, b2, h1, h2)|
      id = "#{mode}/#{app}/#{name}"
      # Workload noise (caches, timestamps, growing data) does not depend on
      # the mode, so the floor is the largest of every mode's.
      floor = modes.map { out[:floors].fetch("#{_1}/#{app}/#{name}", 0) }.max
      # Workloads, and A/A moves <= -1 / >= +1 in the base pair and the head pair.
      stats = out[:aa][mode]
      stats[0] += 1
      [[b1, b2], [h1, h2]].each_with_index do |(x, y), i|
        stats[1 + 2 * i] += 1 if y["gc"] - x["gc"] <= -1
        stats[2 + 2 * i] += 1 if y["gc"] - x["gc"] >= 1
      end
      # The traced count of the same operations must move the same way.
      traced = [h1, h2].product([b1, b2]).map { |x, y| x["traced"] - y["traced"] }
      if (d = moved([b1["gc"], b2["gc"]], [h1["gc"], h2["gc"]], floor)) && traced.all? { _1.nonzero? && _1.positive? == d.positive? }
        out[:workloads] << { mode:, app:, workload: name, kind: h1["kind"], delta: d, floor:,
          base: b2["gc"], head: h2["gc"] }
      end
      digests = [b1, b2, h1, h2].map { _1.dig("sql", "digest") }
      if digests[0] != digests[1] || digests[2] != digests[3]
        out[:sql_unstable] << id
      elsif digests[0] != digests[2]
        out[:sql] << { mode:, app:, workload: name, base: b2["sql"], head: h2["sql"] }
      end
      bsites = [b1, b2].map { _1["sites"] }
      hsites = [h1, h2].map { |r| r["sites"].each_with_object(Hash.new(0.0)) { |(k, v), acc| acc[to_base(repo, base, head, k)] += v } }
      head_key = [h1, h2].flat_map { _1["sites"].keys }.uniq.to_h { [to_base(repo, base, head, _1), _1] }
      (bsites.flat_map(&:keys) | hsites.flat_map(&:keys)).each do |key|
        bv = bsites.map { _1.fetch(key, 0.0) }
        hv = hsites.map { _1.fetch(key, 0.0) }
        site_floor = [floor, aa(bv), aa(hv)].max
        next unless (d = moved(bv, hv, site_floor))
        file = file_of(key)
        net = ->(sites) { sites.sum { |k, v| file_of(k) == file ? v : 0 } }
        file_delta = (hsites.map(&net).min - bsites.map(&net).max).round(1)
        out[:sites] << { mode:, app:, workload: name, kind: h1["kind"], key:, head_key: head_key[key], delta: d.round(1),
          base: bv.max.round(1), head: hv.min.round(1), file_delta:, floor: site_floor }
      end
    end
    out
  end

  # Moved Rails lines aggregated across workloads, broadest first.
  def site_rows(sites, grown:)
    sites.select { (_1[:delta] > 0) == grown && _1[:key].start_with?("RAILS/") }.group_by { _1[:key] }.map do |key, rows|
      { key:, head_key: rows.first[:head_key], new: key.include?(":+"), rows:, apps: rows.map { _1[:app].sub(/-mysql\z/, "") }.uniq,
        modes: rows.map { _1[:mode] }.uniq, max: rows.max_by { _1[:delta].abs },
        net: rows.any? { grown ? _1[:file_delta] > _1[:floor] : _1[:file_delta] < -_1[:floor] } }
    end.sort_by { [-_1[:apps].size, -_1[:rows].size, -_1[:max][:delta].abs] }
  end

  # Controls output lines that differ between base and head, ignoring lines
  # that already differ between the two base runs or the two head runs.
  def control_diff(b1, b2, h1, h2)
    unstable = ->(x, y) { (x.lines.zip(y.lines).each_with_index.reject { |(p, q), _| p == q }.map(&:last)) }
    base, head = b1.lines, h1.lines
    noisy = unstable.(b1, b2) | unstable.(h1, h2)
    by_key = ->(lines) { lines.to_h { [_1[/\A(.*?) => /, 1] || _1, _1.chomp] } }
    bk, hk = by_key.(base), by_key.(head)
    noisy_keys = noisy.flat_map { [base[_1], head[_1]] }.compact.map { _1[/\A(.*?) => /, 1] || _1 }
    keys = (bk.keys | hk.keys) - noisy_keys
    { changed: keys.filter_map { |k| [bk[k], hk[k]] if bk[k] != hk[k] }, noisy: noisy_keys.uniq.size, lines: hk.size }
  end
end
