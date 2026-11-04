# frozen_string_literal: true

# Frontier census (docs/upstream/frontier-census-f1.md): rank ZJIT reasons and
# ZJIT-minus-interpreter allocation sites by apps reached, as `script/census
# rank` ranks Rails lines.
#
#   ruby SCRIPT reasons OUT/LABEL_A OUT/LABEL_B [--min 1]
#     Two `run --stats` labels (ZJIT, --zjit-stats). For each counter under the
#     reason prefixes below: per-operation count by app in both runs. An app is
#     reached when both runs count >= --min per operation. Rows sort by apps
#     reached, then by the summed per-operation count. "drift" is the larger
#     run's excess over the smaller, summed over all apps; a reason is
#     accepted with >= 3 apps and drift <= 5%. Refuses runs with any
#     compile_error_out_of_memory (docs/DECISIONS.md, 2026-11-03).
#   ruby SCRIPT sites OUT/LABEL [OUT/LABEL2] [--min 1]
#     Allocation labels with interpreter and zjit runs. Per workload, ZJIT
#     objects per operation minus interpreter, by allocation site (file:line,
#     class). A site reaches a workload when the difference is >= --min in
#     every given label; rows sort by apps, then workloads, then the summed
#     smallest difference.
#   Add --tsv for tab-separated output.
require "json"

PREFIXES = %w[send_fallback_ exit_ unspecialized_send_def_type_ complex_arg_pass_ getivar_fallback_
  setivar_fallback_ invokeblock_handler_ compile_error_ not_inlined_cfuncs_ not_annotated_cfuncs_].freeze

args = ARGV.dup
tsv = args.delete("--tsv")
min = args.include?("--min") ? Float(args.slice!(args.index("--min"), 2).last) : 1.0
command, *dirs = args

def app_of(path, mode) = File.basename(path).delete_suffix("-#{mode}.json")

# fizzy-mysql and APP-nops are configurations of one app; breadth counts apps.
def base_app(config) = config.sub(/-(mysql|nops)\z/, "")

case command
when "reasons"
  raise "reasons needs two labels" unless dirs.size == 2
  full = []
  runs = dirs.map do |dir|
    Dir[File.join(dir, "*-zjit.json")].to_h do |f|
      json = JSON.parse(File.read(f))
      full << app_of(f, "zjit") if json.values_at("per_op", "totals").compact.any? { _1.fetch("compile_error_out_of_memory", 0).positive? }
      [app_of(f, "zjit"), json.fetch("per_op")]
    end
  end
  full.uniq!
  raise "ZJIT ran out of executable memory in #{full.sort.join(", ")}; rerun with --zjit-exec-mem-size" if full.any?
  apps = runs.map(&:keys).reduce(:&).sort
  keys = apps.flat_map { |a| runs.flat_map { _1[a].keys } }.uniq.select { |k| PREFIXES.any? { k.start_with?(_1) } }
  rows = keys.map do |key|
    per_app = apps.to_h { |a| [a, runs.map { _1[a].fetch(key, 0.0) }] }
    reached = per_app.select { |_, (x, y)| x >= min && y >= min }.keys.map { base_app(_1) }.uniq
    totals = runs.each_index.map { |i| per_app.values.sum { _1[i] } }
    drift = totals.max.zero? ? 0.0 : (totals.max - totals.min) / totals.min.clamp(1e-9, nil)
    { key: key, apps: reached, per_op: totals.sum / 2, totals: totals, drift: drift,
      accepted: reached.size >= 3 && drift <= 0.05, by_app: per_app }
  end
  rows = rows.reject { _1[:apps].empty? }.sort_by { [-_1[:apps].size, -_1[:per_op]] }
  if tsv
    puts %w[reason apps per_op_sum run_a run_b drift accepted apps_reached].join("\t")
    rows.each { |r| puts [r[:key], r[:apps].size, r[:per_op].round(1), *r[:totals].map { _1.round(1) }, r[:drift].round(4), r[:accepted], r[:apps].join(",")].join("\t") }
  else
    puts "#{apps.map { base_app(_1) }.uniq.size} apps (#{apps.size} configurations): #{apps.join(", ")}"
    puts format("%-58s %4s %12s %7s  %s", "reason", "apps", "per op (sum)", "drift", "")
    rows.each do |r|
      puts format("%-58s %4d %12.1f %6.1f%%  %s", r[:key], r[:apps].size, r[:per_op], r[:drift] * 100, r[:accepted] ? "accepted" : "")
    end
  end
when "sites"
  raise "sites needs one or two labels" unless (1..2).cover?(dirs.size)
  # deltas[label][[app, workload]][site] = zjit - interpreter objects per op
  deltas = dirs.map do |dir|
    Dir[File.join(dir, "*-zjit.json")].each_with_object({}) do |zf, acc|
      app = app_of(zf, "zjit")
      inf = File.join(dir, "#{app}-interpreter.json")
      next unless File.exist?(inf)
      z, i = [zf, inf].map { |f| JSON.parse(File.read(f))["workloads"].to_h { [_1["workload"], _1["sites"]] } }
      (z.keys & i.keys).each do |w|
        sum = Hash.new(0.0)
        z[w].each { sum["#{_1["file"]}:#{_1["line"]} #{_1["class"]}"] += _1["objects_per_op"] }
        i[w].each { sum["#{_1["file"]}:#{_1["line"]} #{_1["class"]}"] -= _1["objects_per_op"] }
        acc[[app, w]] = sum
      end
    end
  end
  workloads = deltas.map(&:keys).reduce(:&)
  total_workloads = workloads.size
  sites = Hash.new { |h, k| h[k] = { workloads: [], sum: 0.0 } }
  workloads.each do |aw|
    deltas.map { _1[aw].keys }.flatten.uniq.each do |site|
      values = deltas.map { _1[aw].fetch(site, 0.0) }
      next unless values.all? { _1 >= min }
      sites[site][:workloads] << aw
      sites[site][:sum] += values.min
    end
  end
  rows = sites.map { |site, s| { site: site, apps: s[:workloads].map { base_app(_1.first) }.uniq, workloads: s[:workloads].size, sum: s[:sum] } }
    .sort_by { [-_1[:apps].size, -_1[:workloads], -_1[:sum]] }
  if tsv
    puts %w[site apps workloads share objects_per_op_sum apps_reached].join("\t")
    rows.each { |r| puts [r[:site], r[:apps].size, r[:workloads], (r[:workloads].fdiv(total_workloads)).round(3), r[:sum].round(1), r[:apps].sort.join(",")].join("\t") }
  else
    puts "#{workloads.map { base_app(_1.first) }.uniq.size} apps, #{total_workloads} workloads; ZJIT minus interpreter >= #{min} in #{dirs.size} label(s)"
    rows.first(40).each do |r|
      puts format("%3d apps %4d wl %8.1f  %s", r[:apps].size, r[:workloads], r[:sum], r[:site])
    end
  end
when "traces"
  # Two directories of jit_parity_fxt.rb TSVs, one CONFIG.tsv per configuration
  # and trace run. Sites are normalized (RAILS/, GEM/, APP/); configurations of
  # one app (fizzy-mysql, *-nops) count as that app, and a site reaches an app
  # when both runs sampled it there. Samples cover the whole process, warmup
  # included, so they attribute reasons to sites; the reasons mode gives rates.
  raise "traces needs two directories" unless dirs.size == 2
  norm = lambda do |site|
    site.sub(%r{/\S*/bundler/gems/rails-\h+/}, "RAILS/").sub(%r{/\S*/gems/[^/ ]+/gems/}, "GEM/")
      .sub(%r{/\S*/\.corpus/censusf1-[^/]+/}, "APP/")
  end
  runs = dirs.map do |dir|
    Dir[File.join(dir, "*.tsv")].each_with_object(Hash.new { |h, k| h[k] = Hash.new(0) }) do |path, acc|
      app = File.basename(path, ".tsv").sub(/-(mysql|nops)\z/, "")
      File.readlines(path).drop(1).each do |line|
        category, reason, site, samples = line.chomp.split("\t")
        acc[[category, reason, norm.(site.to_s)]][app] += samples.to_i
      end
    end
  end
  rows = (runs[0].keys & runs[1].keys).map do |key|
    apps = runs[0][key].keys & runs[1][key].keys
    { key: key, apps: apps.sort, samples: runs.map { |r| apps.sum { r[key][_1] } } }
  end.reject { _1[:apps].empty? }.sort_by { [-_1[:apps].size, -_1[:samples].sum] }
  puts %w[category reason site apps samples_a samples_b app_names].join("\t") if tsv
  rows.each do |r|
    if tsv
      puts [*r[:key], r[:apps].size, *r[:samples], r[:apps].join(",")].join("\t")
    else
      puts format("%3d apps %8d %8d  %-9s %-48s %s", r[:apps].size, *r[:samples], r[:key][0], r[:key][1][0, 48], r[:key][2])
    end
  end
else
  abort "usage: ruby #{$PROGRAM_NAME} reasons|sites|traces ..."
end
