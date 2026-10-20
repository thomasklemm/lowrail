# frozen_string_literal: true

# Sanitized, auditable numeric export and tables; never loads an application.
require_relative "../request_pairs"

module HotspotReport
  AXES = %w[subsystem component prefix].freeze
  def self.estimate(values)
    RequestPairs.estimate(values, seed: 41231)
  end

  def self.shape(dir)
    data = JSON.parse(File.read(File.join(dir, "samples.json")))
    summary = JSON.parse(File.read(File.join(dir, "summary.json")))
    control = JSON.parse(File.read(File.join(dir, "sampler-controls.json")))
    control["fidelity_all_arms_pct"] = %w[off_a off_b].to_h do |arm|
      [arm, %w[total no_gc].to_h do |mode|
        metric = "instructions_#{mode}"
        values = data.fetch("samples").each_index.map do |round|
          100 * (control.fetch("corrected_samples")[round][arm][metric] / data.fetch("samples")[round][arm][metric] - 1)
        end
        [mode, estimate(values)]
      end]
    end
    fidelity_pass = control.fetch("fidelity_all_arms_pct").values.flat_map(&:values).all? do |value|
      value.fetch(:ci95).all? { _1.abs <= 0.5 }
    end
    control["fidelity_pass"] &&= fidelity_pass
    control["accepted"] &&= fidelity_pass
    groups = data.fetch("workers").values.select { _1["trace"] }.flat_map { _1.fetch("groups") }.uniq.sort
    rounds = data.fetch("samples").each_index.map do |round|
      %w[total no_gc].to_h do |mode|
        captures = %w[trace_a trace_b].map do |arm|
          worker = data.fetch("workers").fetch("#{round}-#{arm}")
          indices = worker.fetch("windows").each_index.select { worker["windows"][_1]["mode"] == mode }
          empty, full = indices.sort_by { worker["windows"][_1]["requests"] }
          before, after = [empty, full].map { worker.fetch("attribution").fetch(_1) }
          denominator = after.fetch("signals") - before.fetch("signals")
          counts = worker.fetch("groups").each_with_index.to_h do |key, id|
            [key, %w[self inclusive].map { after.fetch(_1).fetch(id) - before.fetch(_1).fetch(id) }]
          end
          AXES.each do |axis|
            raise "self does not partition #{dir}/#{round}/#{arm}/#{mode}" unless
              counts.sum { |key, values| key.first == axis ? values.first : 0 } == denominator
          end
          { denominator: denominator, counts: counts }
        end
        denominator = captures.sum { _1.fetch(:denominator) }
        values = groups.to_h do |key|
          counts = [0, 1].map { |index| captures.sum { _1.fetch(:counts).fetch(key, [0, 0]).fetch(index) } }
          [key.join("\t"), counts.map { 100.0 * _1 / denominator }]
        end
        [mode, { denominator: denominator, groups: values }]
      end
    end
    workers = data.fetch("workers").transform_values do |worker|
      value = worker.slice("ruby", "yjit", "heap_anchors", "request_settle", "sampling_seed", "rails", "lock_sha256", "trace")
      value["windows"] = worker.fetch("windows").each_with_index.map do |window, index|
        row = window.slice("mode", "requests", "instructions", "gc_segments")
        row["gc"] = %w[before after].map { |endpoint| window.fetch(endpoint).slice("minor_gc_count", "major_gc_count") }
        row["heap_eden_slots"] = window.fetch("pools_before").values.map { _1.fetch("heap_eden_slots") }
        if worker["trace"]
          capture = worker.fetch("attribution").fetch(index)
          row["capture"] = capture.reject { |key, _| %w[self inclusive].include?(key) }
          row["groups"] = worker.fetch("groups").each_with_index.filter_map do |key, id|
            own, inclusive = capture.fetch("self").fetch(id), capture.fetch("inclusive").fetch(id)
            [key.join("\t"), own, inclusive] unless own.zero? && inclusive.zero?
          end
        end
        row
      end
      value
    end
    fingerprints = data.fetch("workers").values.select { _1["trace"] }.map { _1.slice("rails", "lock_sha256", "gems") }.uniq
    raise "inconsistent app lock/dependencies" unless fingerprints.size == 1
    { "name" => File.basename(dir), "app" => File.basename(dir).split("-").first,
      "route" => data.fetch("route_label"), "format" => data.fetch("format"), "accepted" => control.fetch("accepted"),
      "fingerprint" => fingerprints.first, "baseline_aa" => summary.fetch("aa"),
      "heap" => summary.fetch("heap_capacity"), "heap_matched" => summary.fetch("heap_matched"),
      "jit" => summary.fetch("jit"), "sampler_controls" => control,
      "preflight" => data["valgrind"],
      "protocol" => data.slice("seed", "rounds", "jobs", "requests", "heap_slots", "actual_yjit"),
      "worker_logs" => Dir[File.join(dir, "*.valgrind.log")].sort.to_h do |path|
        [File.basename(path), { "sha256" => Digest::SHA256.file(path).hexdigest,
          "brk_overflow" => File.read(path).include?("brk segment overflow") }]
      end,
      "baseline_prices" => %w[total no_gc].to_h { |mode| [mode, summary["layers"]["off_a"]["instructions_#{mode}"]["value"]] },
      "baseline_aa_intervals" => %w[total no_gc].to_h { |mode| [mode, summary["layers"]["off_b"]["instructions_#{mode}"]["delta_pct"]] },
      "rounds" => rounds, "workers" => workers,
      "samples_sha256" => Digest::SHA256.file(File.join(dir, "samples.json")).hexdigest }
  end

  # Mean of route/format percentages, never a ratio of pooled instructions.
  # A rejected shape stays in the descriptive map; no clean-arm salvage.
  def self.aggregate(shapes)
    keys = shapes.flat_map { _1.fetch("rounds").first.fetch("total").fetch(:groups).keys }.uniq.sort
    rows = keys.to_h do |key|
      values = (0...6).map do |round|
        [0, 1].map do |kind|
          shapes.sum { _1.fetch("rounds")[round].fetch("total").fetch(:groups).fetch(key, [0, 0])[kind] }.fdiv(shapes.size)
        end
      end
      [key, { "self" => estimate(values.map(&:first)), "inclusive" => estimate(values.map(&:last)), "rounds" => values }]
    end
    { "accepted" => shapes.all? { _1.fetch("accepted") }, "shapes" => shapes.map { _1.fetch("name") }, "groups" => rows }
  end

  def self.cell(estimate)
    mid, (low, high) = estimate.values_at(:median, :ci95)
    format("%.2f [%.2f, %.2f]", mid, low, high)
  end

  def self.table(rows, axis, limit: nil)
    selected = rows.select { |key, _| key.start_with?(axis + "\t") }.sort_by { |_, values| -values.fetch("self")[:median] }
    selected = selected.first(limit) if limit
    ["| #{axis.capitalize} | Inclusive % [95% CI] | Self % [95% CI] |", "|---|---:|---:|"] +
      selected.map { |key, values| "| `#{key.split("\t").last}` | #{cell(values.fetch('inclusive'))} | #{cell(values.fetch('self'))} |" }
  end

  def self.detail_family(path)
    if path.include?("/activesupport-")
      family = case path
      when /output_safety|core_ext\/erb\/util/ then "SafeBuffer / ERB::Util"
      when /notifications|subscriber|event_reporter/ then "Notifications / Instrumenter / subscribers"
      when /callbacks/ then "Callbacks"
      when /hash_with_indifferent_access/ then "HashWithIndifferentAccess"
      when /core_ext\/hash/ then "Hash core_ext"
      when /active_support\/json|core_ext\/object\/json/ then "JSON / as_json / to_json"
      when /inflector|core_ext\/string\/inflections/ then "Inflector"
      when /current_attributes/ then "CurrentAttributes"
      when /isolated_execution_state/ then "IsolatedExecutionState"
      when /parameter_filter/ then "ParameterFilter"
      when /message_(encryptor|verifier)|messages\/|key_generator/ then "Message crypto / serializer plumbing"
      when /ordered_options/ then "OrderedOptions / InheritableOptions"
      when /core_ext\/object\/blank/ then "blank? / presence"
      when /core_ext\/object\/try|core_ext\/module\/delegation/ then "try / delegation"
      else "Other ActiveSupport"
      end
      return ["AS", family]
    end
    family = case path
    when /rack-[^\/]+\/lib\/rack\/mock_/ then "MockRequest / MockResponse (client)"
    when /rack-[^\/]+\/lib\/rack\/headers/ then "Rack Headers"
    when /rack-[^\/]+\/lib\/rack\/response/ then "Rack Response"
    when /rack-[^\/]+\/lib\/rack\/(request|query_parser|utils)/ then "Rack Request / query / utils"
    when /rack-[^\/]+\/lib\/rack\/(etag|conditional_get)/ then "Rack ETag / ConditionalGet"
    when /rack-[^\/]+\/lib\/rack\/method_override/ then "Rack MethodOverride"
    when /rack-[^\/]+\/lib\/rack\/(static|files)/ then "Rack Static / Files"
    when /rack-session|action_dispatch\/middleware\/(cookies|session)/ then "Session / cookies (separate original bucket)"
    when /action_dispatch\/middleware\/static/ then "Rails Static miss (separate original bucket)"
    when /action_dispatch\/(journey|routing)/ then "Journey / routing (separate original bucket)"
    when /action_dispatch\/http/ then "Rails Request / Response / HTTP headers"
    when /action_dispatch\// then "Other ActionDispatch envelope"
    when /rack-[^\/]+\/lib\/rack\// then "Other Rack middleware"
    end
    ["HTTP", family] if family
  end

  def self.details(inputs, output)
    exports = inputs.flat_map { Dir[File.join(_1, "*", "details.json")] }.sort.map do |file|
      dir = File.dirname(file)
      coarse = shape(dir)
      data = JSON.parse(File.read(File.join(dir, "samples.json")))
      raw = JSON.parse(File.read(file))
      raw.each_value do |worker|
        worker.fetch("frames").each do |frame|
          frame[0] = frame[0].sub(%r{.*/gems/}, "GEM/").sub(%r{.*?/\.corpus/[^/]+/}, "APP/")
            .sub(%r{.*?/lib/ruby/\d+\.\d+\.\d+/}, "RUBY/")
          frame[0] = "Benchmark client/seam" if frame[0].include?("/bench/")
        end
      end
      rounds = data.fetch("samples").each_index.map do |round|
        totals = Hash.new { |hash, key| hash[key] = [0, 0, 0, 0] }
        denominator = 0
        %w[trace_a trace_b].each do |arm|
          key = "#{round}-#{arm}"
          worker = data.fetch("workers").fetch(key)
          indices = worker.fetch("windows").each_index.select { worker["windows"][_1]["mode"] == "total" }
          empty, full = indices.sort_by { worker["windows"][_1]["requests"] }
          denominator += worker["attribution"][full]["signals"] - worker["attribution"][empty]["signals"]
          gc = worker["attribution"][full]["gc"] - worker["attribution"][empty]["gc"]
          totals["method\tGC"][0] += gc
          capture = raw.fetch(key)
          capture.fetch("stacks").each do |ids, counts|
            delta = counts[full] - counts[empty]
            next if delta.zero?
            frames = ids.map { capture.fetch("frames").fetch(_1) }
            inside = frames.any? { |path, method, _| path.end_with?("/action_controller/metal/basic_implicit_render.rb") && method&.end_with?("#send_action") }
            engine = frames.any? { |path, method, _| path.end_with?("/rails/engine.rb") && method == "Rails::Engine#call" }
            client = !engine && frames.any? { |path, _, _| path.match?(%r{/rack/mock_(request|response)\.rb\z}) }
            groups = frames.map do |path, method, _|
              [["method", "#{path} :: #{method}"], ["file", path], detail_family(path)].compact.map { _1.join("\t") }
            end
            own = groups.first || ["method\tBenchmark client/seam"]
            own.each do |group|
              totals[group][0] += delta
              totals[group][2] += delta if inside
              totals[group][3] += delta if client
            end
            groups.flatten.uniq.each { totals[_1][1] += delta }
          end
        end
        raise "detail self partition mismatch" unless totals.sum { |key, values| key.start_with?("method\t") ? values.first : 0 } == denominator
        [denominator, totals.transform_values { _1.map { |count| 100.0 * count / denominator } }]
      end
      keys = rounds.flat_map { _1.last.keys }.uniq
      keys |= ["AS\tSafeBuffer / ERB::Util", "AS\tCurrentAttributes", "AS\tJSON / as_json / to_json"]
      groups = keys.to_h do |key|
        values = rounds.map { _1.last.fetch(key, [0, 0, 0, 0]) }
        [key, %w[self inclusive inside_action mock_phase].each_with_index.to_h { |kind, i| [kind, estimate(values.map { _1[i] })] }.merge("rounds" => values)]
      end
      { name: coarse.fetch("name"), accepted: coarse.fetch("accepted"), controls: coarse.fetch("sampler_controls"),
        baseline_aa: coarse.fetch("baseline_aa_intervals"), heap_matched: coarse.fetch("heap_matched"),
        fingerprint: coarse.fetch("fingerprint"), groups: groups, denominators: rounds.map(&:first),
        frame_dictionary: raw.values.flat_map { _1.fetch("frames") }.uniq,
        worker_logs: coarse.fetch("worker_logs"), preflight: coarse.fetch("preflight"),
        details_sha256: Digest::SHA256.file(file).hexdigest,
        provenance: JSON.parse(File.read(File.join(File.dirname(dir), "provenance.json"))) }
    end
    File.write(output, JSON.pretty_generate(shapes: exports) + "\n")
    lines = ["## Source/method detail cohorts", "", "Separate finite cohorts; no replacement of the original accepted maps or borrowed controls.", ""]
    exports.each do |shape|
      lines += ["### #{shape[:name]}", "", "**#{shape[:accepted] ? 'Accepted' : 'REJECTED / diagnostic'}**. All shares below use the whole request denominator.", ""]
      %w[AS HTTP].each do |axis|
        lines += ["#### #{axis} self by source family", "", "| Family | Self % [95% CI] | Inside action/render self % | Mock-client/body-consumption phase self % |", "|---|---:|---:|---:|"]
        shape[:groups].select { |key, _| key.start_with?(axis + "\t") }.sort_by { |_, value| -value["self"][:median] }.each do |key, value|
          lines << "| #{key.split("\t").last} | #{cell(value['self'])} | #{cell(value['inside_action'])} | #{cell(value['mock_phase'])} |"
        end
        lines += [""]
      end
      lines += ["#### Top self methods", "", "| File :: method | Self % [95% CI] | Inclusive % [95% CI] | Inside action/render self % | Mock-client/body-consumption phase self % |", "|---|---:|---:|---:|---:|"]
      shape[:groups].select { |key, _| key.start_with?("method\t") }.sort_by { |_, value| -value["self"][:median] }.first(12).each do |key, value|
        lines << "| `#{key.split("\t").last}` | #{cell(value['self'])} | #{cell(value['inclusive'])} | #{cell(value['inside_action'])} | #{cell(value['mock_phase'])} |"
      end
      lines += [""]
    end
    File.write(output.sub(/\.json\z/, "-tables.md"), lines.join("\n") + "\n")
    puts JSON.generate(shapes: exports.map { _1.slice(:name, :accepted) })
  end

  def self.run(inputs, output)
    shapes = inputs.flat_map { Dir[File.join(File.expand_path(_1), "*", "sampler-controls.json")] }.sort.map { shape(File.dirname(_1)) }
      .sort_by { [%w[blog starter pingcrm redprints campfire].index(_1.fetch("app")), _1.fetch("name")] }
    raise "no finished cohorts" if shapes.empty?
    apps = shapes.group_by { _1.fetch("app") }.transform_values { aggregate(_1) }
    primary = apps.reject { |name, _| name == "campfire" }
    keys = primary.values.flat_map { _1.fetch("groups").keys }.uniq
    ranking = keys.select { _1.start_with?("subsystem\t") && _1 != "subsystem\tBenchmark client/seam" }.to_h do |key|
      values = (0...6).map do |round|
        primary.values.sum { _1.fetch("groups").dig(key, "rounds", round, 0) || 0 }.fdiv(primary.size)
      end
      [key, estimate(values)]
    end.sort_by { |_, value| -value[:median] }.to_h
    provenance = inputs.map { JSON.parse(File.read(File.join(_1, "provenance.json"))) }
    provenance.each { _1.delete("valgrind") }
    interrupted = inputs.flat_map { Dir[File.join(_1, "*", "*.valgrind.log")] }.group_by { File.dirname(_1) }.filter_map do |dir, logs|
      next if File.exist?(File.join(dir, "sampler-controls.json"))
      next unless logs.any? { File.read(_1).include?("brk segment overflow") }
      data = JSON.parse(File.read(File.join(dir, "samples.json")))
      { name: File.basename(dir), accepted: false, reason: "brk segment overflow; interrupted, no partial-arm salvage",
        aggregated_rounds: data.fetch("samples").size,
        samples_sha256: Digest::SHA256.file(File.join(dir, "samples.json")).hexdigest,
        worker_logs: logs.sort.to_h do |path|
          [File.basename(path), { sha256: Digest::SHA256.file(path).hexdigest,
            brk_overflow: File.read(path).include?("brk segment overflow") }]
        end }
    end
    export = { schema: 1, metric: "Callgrind Ir-triggered interpreter stack samples", allocation_census: "allocations.md (not repeated)",
      provenance: provenance, interrupted_rejections: interrupted, shapes: shapes, apps: apps,
      primary_ranking_accepted: primary.values.all? { _1.fetch("accepted") }, primary_ranking: ranking }
    File.write(output, JSON.pretty_generate(export) + "\n")
    lines = ["## Cohort controls", "", "Rejected means the entire request-shape cohort is diagnostic; it is not rerun or salvaged.", "",
      "| Request shape | Total / no-GC M Ir | Baseline A/A CI %, total / no-GC | Heap | Sampler A/A | Fidelity | Capture | Verdict |",
      "|---|---:|---|---|---|---|---|---|"]
    shapes.each do |shape|
      control = shape.fetch("sampler_controls")
      prices = shape.fetch("baseline_prices").values.map { format("%.3f", _1.fetch("median") / 1e6) }.join(" / ")
      aa = shape.fetch("baseline_aa_intervals").values.map { "[#{_1.fetch('ci95').map { |v| format('%+.4f', v) }.join(', ')}]" }.join(" / ")
      lines << "| #{shape.fetch('name')} | #{prices} | #{aa} | #{shape['heap_matched'] ? 'pass' : 'FAIL'} | #{control.dig('sampler_aa', 'aa', 'pass') ? 'pass' : 'FAIL'} | #{control['fidelity_pass'] ? 'pass' : 'FAIL'} | #{control['integrity'] ? 'pass' : 'FAIL'} | **#{shape['accepted'] ? 'accepted' : 'REJECTED'}** |"
    end
    lines += ["", "## Route/format detail", "", "Five largest self costs per request shape; intervals include all six rounds.", "",
      "| Request shape | Subsystem | Inclusive % [95% CI] | Self % [95% CI] |", "|---|---|---:|---:|"]
    shapes.each do |shape|
      aggregate([shape]).fetch("groups").select { |key, _| key.start_with?("subsystem\t") }
        .sort_by { |_, value| -value.fetch("self")[:median] }.first(5).each do |key, value|
        lines << "| #{shape.fetch('name')}#{shape.fetch('accepted') ? '' : ' (REJECTED)'} | #{key.split("\t").last} | #{cell(value.fetch('inclusive'))} | #{cell(value.fetch('self'))} |"
      end
    end
    apps.each do |name, app|
      lines += ["", "## #{name}", "", "Equal shape weights: #{app.fetch('shapes').join(', ')}.", "",
        app.fetch("accepted") ? "All constituent cohorts accepted." : "**Descriptive: at least one constituent cohort is rejected.**", ""]
      lines += table(app.fetch("groups"), "subsystem")
      lines += ["", "### Rails components and gems", ""] + table(app.fetch("groups"), "component", limit: 12)
      lines += ["", "### Gem/file prefixes (top self costs)", ""] + table(app.fetch("groups"), "prefix", limit: 10)
    end
    lines += ["", "## Cross-app self-cost ranking", "", "Equal weight per available primary app (#{primary.keys.join(', ')}), then per measured route/format. Campfire is excluded.", "",
      primary.values.all? { _1.fetch("accepted") } ? "All constituent cohorts accepted." : "**Descriptive: includes a rejected cohort; not an accepted aggregate.**", "",
      "| Rank | Subsystem | Mean self % [95% CI] |", "|---:|---|---:|"]
    ranking.first(12).each_with_index { |(key, value), i| lines << "| #{i + 1} | #{key.split("\t").last} | #{cell(value)} |" }
    File.write(output.sub(/\.json\z/, "-tables.md"), lines.join("\n") + "\n")
    document = output.sub(/-results\.json\z/, ".md")
    if document != output && File.file?(document)
      File.write(document, File.read(document).sub(/<!-- BEGIN GENERATED HOTSPOT TABLES -->.*<!-- END GENERATED HOTSPOT TABLES -->/m) do
        "<!-- BEGIN GENERATED HOTSPOT TABLES -->\n\n#{lines.join("\n")}\n\n<!-- END GENERATED HOTSPOT TABLES -->"
      end)
    end
    puts JSON.pretty_generate(shapes: shapes.size, accepted: shapes.count { _1.fetch("accepted") },
      primary_top_five: ranking.first(5), app_top_five: apps.transform_values do |app|
        app.fetch("groups").select { |key, _| key.start_with?("subsystem\t") }.sort_by { |_, value| -value["self"][:median] }.first(5).to_h
      end)
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.first == "--detail"
    ARGV.shift
    HotspotReport.details(ARGV.drop(1), File.expand_path(ARGV.first))
    exit
  end
  abort "usage: hotspots_report.rb OUT.json INPUT_DIR..." if ARGV.size < 2
  HotspotReport.run(ARGV.drop(1), File.expand_path(ARGV.first))
end
