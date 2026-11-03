# frozen_string_literal: true

# Census 8 ranking: Rails lines or methods by sampled self instructions, breadth
# first. A site reaches a workload at >= REACH Ir per operation; apps are
# counted once (fizzy-mysql, mastodon-nops and lago-nops are their apps).
# Within a tier, by mean Ir per operation over every workload of every app.
# The objects column comes from a script/census label of the same corpus.
require "json"
require_relative "../census/rank"

module CpuRank
  TIERS = [7, 5, 3, 2].freeze
  REACH = 5_000

  module_function

  # YJIT windows that compiled anything fail the JIT-flat gate and are left out
  # (counted in `excluded`), never rerun until green.
  def load_runs(dir, mode)
    Dir["#{dir}/*-#{mode}.json"].sort.map do |path|
      run = JSON.parse(File.read(path))
      flat, rejected = run["workloads"].partition { _1.fetch("jit_flat", true) }
      run.merge("workloads" => flat, "excluded" => rejected.map { _1["workload"] })
    end
  end

  def rails(file) = (file.delete_prefix("RAILS/") if file.start_with?("RAILS/"))

  def entries(w, by)
    if by == "method"
      w["methods"].filter_map { |m| (f = rails(m["file"])) && ["#{f}:#{m["line"]} #{m["method"]}", m["self_ir_per_op"], m["incl_ir_per_op"]] }
    else
      w["sites"].filter_map { |s| (f = rails(s["file"])) && ["#{f}:#{s["line"]}", s["ir_per_op"], s["native"].fdiv(s["samples"]), s["method"]] }
    end
  end

  # Allocation means per Rails line (script/census label), and per method via
  # the lines the CPU samples placed in that method.
  def objects(census_dir, mode)
    return nil unless census_dir && Dir.exist?(census_dir)
    runs = CensusRank.load_runs(census_dir, mode)
    total = runs.sum { _1["workloads"].size }
    sums = Hash.new(0.0)
    runs.each { |r| r["workloads"].each { |w| w["sites"].each { |s| (f = rails(s["file"])) && sums["#{f}:#{s["line"]}"] += s["objects_per_op"] } } }
    sums.transform_values { _1 / total }
  end

  def rows(runs, by: "line", tiers: TIERS, reach: REACH, objects: nil)
    workloads = runs.flat_map { |run| run["workloads"].map { [run["app"], _1] } }
    total = workloads.size
    total_ir = workloads.sum { _2["ir_per_op"] } / total
    sites = Hash.new { |h, k| h[k] = { per: Hash.new(0.0), extra: Hash.new(0.0), labels: Hash.new(0), lines: {} } }
    workloads.each do |app, w|
      w["sites"].each { |s| (f = rails(s["file"])) && sites["method:#{f}:#{s["method"]}"][:lines]["#{f}:#{s["line"]}"] = true } if by == "method"
      entries(w, by).each do |key, ir, extra, label|
        site = sites[key]
        site[:per][[app, w["workload"], w["kind"]]] += ir
        site[:extra][:sum] += by == "method" ? extra : extra * ir
        site[:labels][label] += 1 if label
      end
    end
    tier = ->(apps) { tiers.index { apps >= _1 } || tiers.size }
    rows = sites.filter_map do |key, data|
      next if key.start_with?("method:")
      hit = data[:per].select { |_, v| v >= reach }
      apps = hit.keys.map { CensusRank.app_of(_1[0]) }.uniq
      next if apps.empty?
      mean = data[:per].values.sum / total
      row = { site: key, apps: apps.size, app_names: apps.sort, share: hit.size.fdiv(total), kinds: hit.keys.map { _1[2] }.uniq.sort,
        mean: mean, pct: 100 * mean / total_ir }
      if by == "method"
        row[:incl] = data[:extra][:sum] / total
        file, label = key[/\A[^:]+/], key.split(" ", 2)[1]
        lines = sites["method:#{file}:#{label}"][:lines].keys
        row[:objects] = lines.sum { objects[_1] || 0 } if objects
      else
        row[:native] = data[:extra][:sum] / data[:per].values.sum
        row[:method] = data[:labels].max_by { _2 }&.first
        row[:objects] = objects[key] || 0 if objects
      end
      row
    end
    rows.sort_by { [tier.(_1[:apps]), -_1[:mean]] }
  end

  def tsv(rows, by)
    head = %w[rank site apps share mean_ir_per_op pct_of_all_ir]
    head += by == "method" ? %w[incl_ir_per_op] : %w[native_share method]
    head += %w[objects_per_op kinds app_names]
    lines = [head.join("\t")]
    rows.each_with_index do |r, i|
      cols = [i + 1, r[:site], r[:apps], r[:share].round(3), r[:mean].round(0), r[:pct].round(4)]
      cols += by == "method" ? [r[:incl].round(0)] : [r[:native].round(3), r[:method]]
      cols += [r[:objects]&.round(2), r[:kinds].join(","), r[:app_names].join(",")]
      lines << cols.join("\t")
    end
    lines.join("\n") + "\n"
  end

  def text(runs, rows, by, mode, limit)
    total = runs.sum { _1["workloads"].size }
    excluded = runs.sum { _1["excluded"].size }
    out = ["#{runs.size} runs, #{runs.map { CensusRank.app_of(_1["app"]) }.uniq.size} apps, #{total} workloads (#{mode}, by #{by}); " \
      "#{excluded} not JIT-flat, left out"]
    rows.first(limit).each_with_index do |r, i|
      detail = by == "method" ? format("incl %9.0f", r[:incl]) : format("native %3.0f%% %s", 100 * r[:native], r[:method].to_s[0, 50])
      objects = r[:objects] ? format(" obj %6.2f", r[:objects]) : ""
      out << format("%3d %-70s apps %2d share %3.0f%% Ir/op %8.0f (%5.2f%%)%s %s", i + 1, r[:site][0, 70], r[:apps], 100 * r[:share],
        r[:mean], r[:pct], objects, detail)
    end
    out.join("\n") + "\n"
  end

  def command(opts)
    runs = load_runs(File.join(opts[:out], opts.fetch(:label)), opts[:mode])
    raise "no #{opts[:mode]} runs for #{opts[:label]}" if runs.empty?
    census = opts[:objects] && File.join(opts[:census_out] || File.join(CpuCensus::ROOT, ".lowrail/private/census"), opts[:objects])
    rows = rows(runs, by: opts[:by], tiers: opts[:tiers], objects: objects(census, opts[:mode]))
    tsv = File.join(opts[:out], "rank-#{opts[:label]}-#{opts[:mode]}-#{opts[:by]}.tsv")
    File.write(tsv, tsv(rows, opts[:by]))
    print text(runs, rows, opts[:by], opts[:mode], opts[:limit])
    warn "full ranking: #{tsv}"
  end

  def median(a) = a.sort[a.size / 2]

  def per_workload(dir, file) = JSON.parse(File.read(File.join(dir, file)))["workloads"].to_h { [_1["workload"], _1] }

  # Per app and mode: median and spread of the relative change in client Ir
  # per operation, LABEL against BASE, over workloads JIT-flat in both; ALL
  # lines over every such workload.
  def compare(opts, labels)
    base = File.join(opts[:out], opts.fetch(:base))
    labels = [opts[:aa], *labels].compact
    labels.each do |label|
      puts "== #{label} vs #{opts[:base]}"
      all = Hash.new { |h, k| h[k] = [] }
      Dir["#{base}/*.json"].map { File.basename(_1) }.grep(/-(interpreter|yjit)\.json\z/).sort.each do |file|
        other = File.join(opts[:out], label, file)
        next unless File.exist?(other)
        b = per_workload(base, file)
        a = per_workload(File.join(opts[:out], label), file)
        # JIT-flat in both runs only (always true for the interpreter).
        d = b.keys.select { a[_1] && b[_1]["jit_flat"] && a[_1]["jit_flat"] }
          .to_h { [_1, 100 * (a[_1]["ir_per_op"] / b[_1]["ir_per_op"] - 1)] }
        next if d.empty?
        mode = file[/-(\w+)\.json\z/, 1]
        all[mode].concat(d.values)
        printf("%-30s workloads %2d median %+6.2f%% min %+6.2f%% max %+6.2f%%\n", file.delete_suffix(".json"), d.size,
          median(d.values), d.values.min, d.values.max)
      end
      all.each do |mode, d|
        printf("ALL %-11s workloads %3d median %+6.2f%% |d| p90 %5.2f%% lower by >= 1%%: %3d higher by >= 1%%: %3d\n", mode, d.size,
          median(d), d.map(&:abs).sort[(d.size * 0.9).floor] || 0, d.count { _1 <= -1 }, d.count { _1 >= 1 })
      end
    end
  end
end
