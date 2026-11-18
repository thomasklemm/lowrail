# frozen_string_literal: true

# The report of script/census app: per workload objects and instructions with
# their A/A differences, the Rails, Ruby and gem lines that allocate and run the
# most, and the open rails/rails PRs and Lowrail ledger entries that touch them.
require "json"
require_relative "rank"

module CensusAppReport
  RANKED = %w[RAILS GEM RUBY].freeze
  ORIGINS = { "RAILS" => "Rails", "GEM" => "Gems", "RUBY" => "Ruby standard library", "APP" => "The app's own code" }.freeze
  LEDGER = File.expand_path("../../../docs/upstream/contributions.md", __dir__)
  # Method names too common to identify a ledger entry.
  COMMON = %w[call each map new initialize to_s to_h to_a render inspect hash first last get set fetch value
    values key keys name path build run perform process].freeze

  module_function

  def median(a) = a.sort[a.size / 2]

  def load(path) = (JSON.parse(File.read(path)) if File.exist?(path))

  def num(v, digits = 0)
    return "–" if v.nil?
    int, frac = format("%.#{digits}f", v.abs).split(".")
    (v.round(digits).negative? ? "−" : "") + int.reverse.scan(/\d{1,3}/).join(",").reverse + (frac ? ".#{frac}" : "")
  end

  def signed(v, digits = 1) = v.nil? ? "–" : (v.round(digits).zero? ? "±0" : (v.positive? ? "+" : "−") + num(v.abs, digits))

  def pct(v) = v.nil? ? "–" : format("%+.2f%%", v).sub("-", "−")

  def harness?(file)
    # The workloads file's own blocks run in the copy, keyed APP/.census-app/.
    file.start_with?("LOWRAIL/", "APP/.census-app/") || (CensusRank.gem_name(file) && CensusRank::HARNESS_GEMS.include?(CensusRank.gem_name(file))) ||
      file.match?(%r{\AGEM/.*/rack-[\d.]+/lib/rack/mock_(?:request|response)\.rb\z})
  end

  def origin(file) = file[/\A(RAILS|GEM|RUBY|APP)\//, 1] || "other"

  # Per line: the mean over every workload (objects or instructions per
  # operation), the workloads reaching it and its main class or method.
  def lines(runs, value, label, reach)
    workloads = runs["workloads"]
    rows = Hash.new { |h, k| h[k] = { sum: 0.0, reached: 0, labels: Hash.new(0.0) } }
    workloads.each do |w|
      per = Hash.new(0.0)
      w["sites"].each do |s|
        next if s["file"].nil? || harness?(s["file"])
        key = "#{s["file"]}:#{s["line"]}"
        per[key] += s[value]
        rows[key][:labels][s[label].to_s] += s[value]
      end
      per.each { |k, v| rows[k][:sum] += v; rows[k][:reached] += 1 if v >= reach }
    end
    rows.to_h { |k, r| [k, { mean: r[:sum] / workloads.size, reached: r[:reached], label: r[:labels].max_by { _2 }&.first }] }
  end

  def source_path(key, roots)
    file = key.sub(/:\d+\z/, "")
    prefix, rest = file.split("/", 2)
    base = roots&.dig(prefix)
    return nil unless base && rest
    if base.is_a?(Hash) # RAILS on released gems: RAILS/COMPONENT/...
      component, rest = rest.split("/", 2)
      base = base[component] or return nil
    end
    File.join(base, rest)
  end

  def source(key, roots)
    path = source_path(key, roots)
    return nil unless path && File.exist?(path)
    (@sources ||= {})[path] ||= File.readlines(path)
    [path, @sources[path]]
  end

  def text(key, roots)
    _, src = source(key, roots)
    line = src&.[](Integer(key[/:(\d+)\z/, 1]) - 1)&.strip
    line && "`#{line.length > 70 ? line[0, 67] + "..." : line}`".gsub("|", "\\|")
  end

  # The method a line is in: the CPU sampler's label, else the nearest def above it.
  def method_name(key, roots, label = nil)
    return label.split(/[#.]/).last if label && label.match?(/[#.]\w/)
    _, src = source(key, roots)
    return nil unless src
    src[0, Integer(key[/:(\d+)\z/, 1])].reverse_each { |l| return $1 if l =~ /^\s*def\s+(?:self\.)?([\w]+[?!=]?)/ }
    nil
  end

  # contributions.md bullets by section, each with its first PR link or ID.
  def ledger
    @ledger ||= begin
      section = nil
      File.readlines(LEDGER).filter_map do |l|
        section = l[/^## (.+)/, 1].strip if l.start_with?("## ")
        next unless l.start_with?("- ", "* ") && section
        ref = l[/\[((?:[\w.-]+\/[\w.-]+)?#\d+)\]/, 1] || l[/\*\*([^*]{2,60})\*\*/, 1]&.sub(/[:.]\z/, "") || l[2, 50].strip + "..."
        id = l[/\]\([^)]*\)\s*\(([A-Z][\w-]*\d\w*)[,)]/, 1]
        { section: section, ref: ref, id: id, text: l }
      end
    end
  end

  COMPONENTS = { "actioncable" => "Action Cable", "actionmailbox" => "Action Mailbox", "actionmailer" => "Action Mailer",
    "actionpack" => "Action Pack", "actiontext" => "Action Text", "actionview" => "Action View", "activejob" => "Active Job",
    "activemodel" => "Active Model", "activerecord" => "Active Record", "activestorage" => "Active Storage",
    "activesupport" => "Active Support", "railties" => "Railties" }.freeze

  # An entry that names the line's file, or its method together with its gem
  # or Rails component (a method name alone matches too much).
  def ledger_entries(key, roots, label)
    name = method_name(key, roots, label)
    file = key.sub(/:\d+\z/, "")
    lib = file[%r{/lib/(.+)\z}, 1]
    gem = CensusRank.gem_name(file)
    context = [gem, COMPONENTS[file[%r{\ARAILS/(\w+)/}, 1]], File.basename(file, ".rb")].compact.select { _1.size >= 4 }
    hits = ledger.select do |e|
      (lib && e[:text].include?(lib)) ||
        (name && name.size >= 4 && !COMMON.include?(name) && e[:text].match?(/`[^`]*\b#{Regexp.escape(name)}(?![\w?!=])[^`]*`/) &&
          context.any? { |c| e[:text].match?(/\b#{Regexp.escape(c)}\b/i) })
    end
    hits.first(3).map { "ledger: #{_1[:ref]}#{" (#{_1[:id]})" if _1[:id]}, #{_1[:section].downcase}" }
  end

  def open_prs(refresh)
    @open_prs ||= begin
      cache = File.join(Census::ROOT, ".lowrail/private/census/open-rails-prs.json")
      data = Census.open_prs(cache, refresh)
      by_file = Hash.new { |h, k| h[k] = [] }
      data["prs"].each { |pr| pr["files"].each { by_file[_1] << pr } }
      [data, by_file, cache]
    rescue RuntimeError, Errno::ENOENT => e
      warn "open rails/rails PRs not checked: #{e.message} (needs gh, signed in)"
      [nil, {}, nil]
    end
  end

  def prs(key, refresh, own)
    return [] unless key.start_with?("RAILS/")
    data, by_file, = open_prs(refresh)
    return [] unless data
    file = key.delete_prefix("RAILS/").sub(/:\d+\z/, "")
    line = Integer(key[/:(\d+)\z/, 1])
    prs = by_file[file].sort_by { _1["number"] }
    hit, rest = prs.partition do |pr|
      Census.hunks(pr).fetch(file, []).any? { |start, len| line.between?(start, start + len - 1) }
    rescue RuntimeError # gh could not fetch this PR's diff; it still counts as touching the file
      false
    end
    # Hunks are on each PR's base (main); on a released Rails the line numbers differ.
    out = hit.first(3).map { "open PR ##{_1["number"]} #{_1["title"][0, 50].gsub("|", "/")}#{" (line numbers from main)" if own}" }
    out << "#{rest.size} more open #{rest.size > 1 ? "PRs touch" : "PR touches"} this file" if rest.any?
    out
  end

  def known(key, roots, label, refresh, own)
    found = prs(key, refresh, own) + ledger_entries(key, roots, label)
    found.empty? ? "none found" : found.join("; ")
  end

  def origins(run, value)
    totals = Hash.new(0.0)
    run["workloads"].each { |w| w["sites"].each { |s| totals[s["file"].nil? ? "C" : harness?(s["file"]) ? "harness" : origin(s["file"])] += s[value] } }
    n = run["workloads"].size
    Hash.new(0.0).merge(totals.transform_values { _1 / n })
  end

  def write(out, name, labels, state, top:, refresh: false)
    modes = Dir[File.join(out, labels.first, "#{name}-*.json")].map { File.basename(_1, ".json").delete_prefix("#{name}-") }.sort
    o = []
    o << "# Census of #{name}" << ""
    own = load(File.join(out, labels.first, "#{name}-#{modes.first}.json"))
    meta = load(File.join(out, labels.first, "meta.json"))
    o << "App: `#{state["source"]}` (measured on a copy). Rails #{state.dig("base", "version")} (the app's own), " \
      "#{meta["ruby"]}. Measured #{meta.dig("runs", -1, "finished")}, #{own["workloads"].size} workloads, #{modes.join(" and ")}."
    if (manifest = own["workloads_manifest"])
      File.write(File.join(out, "workloads.json"), JSON.pretty_generate(manifest) + "\n")
      counts = %w[requests mails jobs].map { "#{manifest[_1].size} #{_1}" }.join(", ")
      o << "" << "Workloads: #{manifest["sha256"] ? "the workloads file (sha256 `#{manifest["sha256"][0, 12]}`)" : "GET pages discovered from the routes"}, " \
        "#{counts}, plus the jobs those requests enqueue. Every request's method, path and a digest of its params are in " \
        "`workloads.json`, so another run can be checked for the same workloads without reading the file."
    end
    o << "" << "Each workload is one request, job or mail, run in a production boot of the app with its own Gemfile.lock. " \
      "**Objects** are Ruby objects allocated per operation (median of three windows of 20). **Instructions** are CPU " \
      "instructions per operation, counted exactly by Callgrind for the measuring thread. Everything ran twice in separate " \
      "processes (an **A/A pair**): the A/A column is how much the same code moved between the two, the noise floor. " \
      "These are counts of work, not timings; nothing here claims a request gets faster."
    modes.each do |mode|
      o.concat(section(out, name, labels, mode, state, top, refresh, modes.size > 1))
    end
    o << "" << "## Limits" << ""
    o << "* Lines are attributed where the object was allocated or where Ruby was running when an instruction sample hit " \
      "(C functions count for the Ruby line that called them). A line high in this list is where work happens, not proof " \
      "that the work is avoidable; the PRs and ledger entries show where someone already looked."
    o << "* Matches to open PRs use each PR's diff on Rails main; for a released Rails, line numbers differ and a match " \
      "is a hint. Ledger matches are by file or method name."
    o << "* Workloads run with jobs captured (performed as their own workloads), mail delivered to the test deliverer, " \
      "and data from the census's own seeding of a copy, not your production data."
    path = File.join(out, "report.md")
    File.write(path, o.join("\n") + "\n")
    path
  end

  def section(out, name, labels, mode, state, top, refresh, heading)
    file = "#{name}-#{mode}.json"
    a, b = labels.first, "#{labels.first}2"
    run1, run2 = load(File.join(out, a, file)), load(File.join(out, b, file))
    cpu1, cpu2 = load(File.join(out, "cpu", a, file)), load(File.join(out, "cpu", b, file))
    roots = run1["source_roots"]
    own = !!roots&.dig("RAILS").is_a?(Hash)
    o = []
    o << "" << "## #{heading ? "#{mode}: " : ""}Workloads" << ""
    objs = ->(run, w) { run && (m = run["workloads"].find { _1["workload"] == w }) && median(m["gc_enabled_objects_per_op"]) }
    irs = ->(run, w) { run && (m = run["workloads"].find { _1["workload"] == w }) && m["jit_flat"] != false && m["ir_per_op"] }
    o << "| Workload | Kind | Objects/op | A/A | Instructions/op | A/A | SQL queries/op |" << "| --- | --- | ---: | ---: | ---: | ---: | ---: |"
    aa_moved = 0
    run1["workloads"].each do |w|
      n = w["workload"]
      d = objs.(run2, n) - objs.(run1, n)
      aa_moved += 1 if d.abs >= 1
      i1, i2 = irs.(cpu1, n), irs.(cpu2, n)
      o << "| #{n.gsub("|", "/")} | #{w["kind"]} | #{num(objs.(run1, n))} | #{signed(d)} | #{num(i1)} | " \
        "#{i1 && i2 ? pct(100 * (i2 / i1 - 1)) : "–"} | #{w.dig("sql", "queries_per_op")} |"
    end
    o << "" << "A/A: #{aa_moved} of #{run1["workloads"].size} workloads moved by one object or more between two runs of " \
      "the same code. A difference smaller than a workload's A/A is noise.#{cpu1 ? "" : " Instructions were not measured (`--no-cpu`, or no patched Valgrind: `script/cpu-census build`)."}"

    o << "" << "### Where the objects come from" << ""
    shares = origins(run1, "objects_per_op")
    total = shares.values.sum
    o << "Mean objects per operation over all workloads, by where they were allocated:" << ""
    ORIGINS.each { |k, label| o << "* #{label}: #{num(shares[k], 1)} (#{(100 * shares[k] / total).round}%)" }
    o << "* Without a Ruby line (allocated in C with no Ruby caller): #{num(shares["C"], 1)}" if shares["C"].positive?
    o << "* The census's own request client (not your app): #{num(shares["harness"], 1)}" if shares["harness"].positive?

    ranking = lambda do |title, r1, r2, value, label, reach, unit, total_value|
      l1, l2 = lines(r1, value, label, reach), lines(r2, value, label, reach)
      ranked = l1.select { |k, _| RANKED.include?(origin(k)) }.sort_by { -_2[:mean] }.first(top)
      o << "" << "### #{title}" << ""
      o << "| # | Line | Source | #{unit}/op | A/A | Workloads | #{value == "objects_per_op" ? "Main class" : "Method"} | Known work |"
      o << "| ---: | --- | --- | ---: | ---: | ---: | --- | --- |"
      ranked.each_with_index do |(key, r), i|
        mean2 = l2.dig(key, :mean) || 0
        share = total_value ? " (#{format("%.1f", 100 * r[:mean] / total_value)}%)" : ""
        o << "| #{i + 1} | `#{key.sub(%r{\AGEM/(?:[^/]+/)*?gems/}, "GEM/")}` | #{text(key, roots) || "–"} | #{num(r[:mean], value == "objects_per_op" ? 1 : 0)}#{share} | " \
          "#{value == "objects_per_op" ? signed(mean2 - r[:mean]) : pct(r[:mean].positive? ? 100 * (mean2 / r[:mean] - 1) : nil)} | " \
          "#{r[:reached]} of #{r1["workloads"].size} | #{r[:label].to_s.gsub("|", "/")[0, 40]} | " \
          "#{known(key, roots, value == "ir_per_op" ? r[:label] : nil, refresh, own)} |"
      end
    end
    ranking.("Top Rails, Ruby and gem lines by objects", run1, run2, "objects_per_op", "class", CensusRank::REACH, "Objects", nil)
    o << "" << "Objects/op is the mean over all #{run1["workloads"].size} workloads (a line reached by one workload in ten " \
      "with 10 objects shows 1.0); Workloads counts those where it allocates at least #{CensusRank::REACH} per operation."
    if cpu1
      flat = cpu1["workloads"].select { _1.fetch("jit_flat", true) }
      c1, c2 = cpu1.merge("workloads" => flat), cpu2.merge("workloads" => cpu2["workloads"].select { _1.fetch("jit_flat", true) })
      total_ir = flat.sum { _1["ir_per_op"] } / flat.size
      ranking.("Top Rails, Ruby and gem lines by instructions", c1, c2, "ir_per_op", "method", 5_000, "Instructions", total_ir)
      o << "" << "Instructions/op is the mean sampled self cost over all workloads, with its share of all instructions; " \
        "Workloads counts those where the line runs at least 5,000 instructions per operation. Samples are every ~8,192 " \
        "instructions, so lines under a few thousand are noisy; the A/A column shows how much."
      o << "Under YJIT, #{cpu1["workloads"].size - flat.size} workloads that were still compiling are left out." if mode == "yjit"
    end
    o.concat(upgrade(out, name, labels, mode, run1, run2)) if labels.size > 1
    o
  end

  # The other Rails against the app's own, each with its A/A pair.
  def upgrade(out, name, labels, mode, own1, own2)
    file = "#{name}-#{mode}.json"
    l = labels[1]
    m1, m2 = load(File.join(out, l, file)), load(File.join(out, "#{l}2", file))
    c1, c2 = load(File.join(out, "cpu", labels[0], file)), load(File.join(out, "cpu", l, file))
    cm2 = load(File.join(out, "cpu", "#{l}2", file))
    co2 = load(File.join(out, "cpu", "#{labels[0]}2", file))
    meta = load(File.join(out, l, "meta.json"))
    obj = ->(run, w) { (x = run["workloads"].find { _1["workload"] == w }) && median(x["gc_enabled_objects_per_op"]) }
    ir = ->(run, w) { run && (x = run["workloads"].find { _1["workload"] == w }) && x.fetch("jit_flat", true) && x["ir_per_op"] }
    sql = ->(run, w) { run["workloads"].find { _1["workload"] == w }&.dig("sql", "digest") }
    spec, sha = meta.dig("rails", "spec"), meta.dig("rails", "sha")
    o = ["", "### On Rails #{spec.include?(sha) ? sha[0, 10] : "#{spec} (#{sha[0, 10]})"}", ""]
    o << "What the same workloads do on this Rails, against the app's own. A change counts only when it is larger than " \
      "both A/A pairs. Gems the new Rails needs were resolved by Bundler from the app's lock, so a difference can come " \
      "from them too#{meta.dig("runs", -1, "dependencies_outside_rails_match_base", name) == false ? " (here they differ from the app's lock)" : ""}."
    o << "" << "| Workload | Objects/op | Δ | Beyond A/A | Instructions/op | Δ | Beyond A/A | SQL |" << "| --- | ---: | ---: | --- | ---: | ---: | --- | --- |"
    beyond = [0, 0]
    own1["workloads"].each do |w|
      n = w["workload"]
      next o << "| #{n} | – | – | missing on this Rails | | | | |" unless obj.(m1, n)
      d = obj.(m1, n) - obj.(own1, n)
      floor = [(obj.(own2, n) - obj.(own1, n)).abs, (obj.(m2, n) - obj.(m1, n)).abs, 1].max
      ob = d.abs > floor
      beyond[0] += 1 if ob
      i_own, i_new = ir.(c1, n), ir.(c2, n)
      di = i_own && i_new && 100 * (i_new / i_own - 1)
      ifloor = [co2 && ir.(co2, n) && 100 * (ir.(co2, n) / i_own - 1), cm2 && ir.(cm2, n) && i_new && 100 * (ir.(cm2, n) / i_new - 1)].compact.map(&:abs).max if di
      ib = di && ifloor && di.abs > ifloor
      beyond[1] += 1 if ib
      sql_changed = sql.(m1, n) != sql.(own1, n) ? (sql.(own2, n) == sql.(own1, n) && sql.(m2, n) == sql.(m1, n) ? "changed" : "unstable") : "same"
      o << "| #{n.gsub("|", "/")} | #{num(obj.(m1, n))} | #{signed(d)} | #{ob ? "yes" : "no"} | #{num(i_new)} | #{pct(di)} | " \
        "#{di ? (ib ? "yes" : "no") : "–"} | #{sql_changed} |"
    end
    o << "" << "#{beyond[0]} workloads moved beyond their A/A in objects#{c2 ? " and #{beyond[1]} in instructions" : ""}. " \
      "SQL compares the masked statements each workload runs; \"changed\" means both pairs were stable and differ."
    shares = [origins(own1, "objects_per_op"), origins(m1, "objects_per_op")]
    o << "" << "Objects per operation by origin, mean over workloads (app's Rails → this Rails): " +
      ORIGINS.map { |k, label| "#{label} #{num(shares[0][k], 1)} → #{num(shares[1][k], 1)}" }.join("; ") + "."
    o
  end
end
