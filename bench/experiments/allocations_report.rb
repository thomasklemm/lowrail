# frozen_string_literal: true

# Deterministic numeric export and generated tables; no heap contents/headers.
require "json"
root = File.expand_path("../..", __dir__)
profiles = Dir[File.join(ARGV.fetch(0), "*.json")].reject { _1.end_with?("activation.json") }.sort.to_h do |file|
  p = JSON.parse(File.read(file))
  if file.end_with?("-default.json")
    log = File.read(file.sub(/\.json\z/, "-probe.log"))
    p["activation"] = JSON.parse(log.lines.find { _1.start_with?("LOWRAIL_BENCH ") }.delete_prefix("LOWRAIL_BENCH "))
    p["activation"].merge!(JSON.parse(File.read(file.sub(/\.json\z/, "-activation.json"))))
  end
  [File.basename(file, ".json"), p]
end
raise "expected 30 profiles" unless profiles.size == 30
profiles.each_value do |p|
  raise "bad census" unless p.fetch("enumerated") == p.fetch("callsites").sum { _1.fetch("allocated") } &&
    p.fetch("retained") == p.fetch("callsites").sum { _1.fetch("retained") }
end

def classification(file, line, klass, app)
  case file
  when /tag_helper/ then line == 309 ? "c/tag" : "b/form"
  when /output_safety/ then app == "blog" ? "b/form" : "a/data"
  when /core_ext\/hash\/slice/ then "b/config-bind"
  when /erb\/util|i18n\/utils|helpers\/tags\/base|core_ext\/hash\/keys/ then "b/form"
  when /middleware\/static/ then "c/static"
  when /callbacks/ then "c/callback"
  when /active_record\/integration/ then "c/param"
  when /journey\/visitors/ then "c/route"
  when /metal\/url_for/ then "c/url-options"
  when /associations\/association\.rb/ then "c/keys"
  when /structured_event_subscriber/ then "b/event-path"
  when /importmap_tags_helper/ then "b/preload-tags"
  when /http\/url/ then "b/url-residue"
  when /net\/http\.rb/ then "b/ssr-setup"
  when /net\/http\/header/ then "b/ssr-headers"
  when /props_resolver/ then [81, 89].include?(line) ? "b/tuple" : (line == 82 || line == 90 ? "b/prop-path" : "b/prop-dispatch")
  when /current_attributes/ then "b/tuple"
  when /attribute_set\/builder/ then line == 37 ? "b/attribute-keys" : "a/data"
  when /inflector/ then "b/inflection"
  when /active_model\/attribute_methods/ then "b/store-read"
  when /frozen_record/ then "b/frozen-lookup"
  when /postgresql_adapter/ then "b/pg-types"
  when /arel\/visitors|sanitization|predicate_builder|active_record\/relation\.rb/ then "b/query"
  when /cancan\/rule/ then "b/authorization"
  when /\A<internal:/ then klass == "FrozenRecord::Scope" ? "b/frozen-lookup" : "a/opaque"
  when /uri-|net\/http\/response|base64|content_security_policy|http\/request/ then "a/io"
  when /rack-/ then "a/rack-client"
  when /sqlite3|database_statements|active_model\/attribute\.|active_model\/type|string\.rb|active_record\/result|active_record\/associations\.rb|tzinfo|date_and_time|jbuilder|json-/ then "a/data"
  else raise "unclassified #{file}:#{line}"
  end
end

tables = []
tables << "## Request allocation census\n\nAll values are objects/request. GC total is the median of three 100-request blocks. S/H/A/P/O = String (including SafeBuffer subclasses), Hash, Array, Proc, other **enumerable** objects; residual is GC total minus the bounded trace's enumerable count. Retained is after three full GCs, divided by N=20, not an extrapolated leak rate.\n"
tables << "| App / route / arm | GC total | S | H | A | P | O | Trace residual | Retained |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|"
profiles.each do |id, p|
  n = p.fetch("requests").to_f
  total = p.fetch("totals").map { _1.fetch("total_allocated_objects").fdiv(p.fetch("total_requests_per_block")) }.sort[1]
  values = %w[String Hash Array Proc other].map { p.fetch("types").fetch(_1, {}).fetch("allocated", 0) / n }
  values += [p.fetch("unenumerated") / n, p.fetch("retained") / n]
  tables << "| #{id} | #{format('%.2f', total)} | #{values.map { format('%.2f', _1) }.join(' | ')} |"
end
tables << "\n### Retained by type\n\nCounts are **objects in the whole 20-request window**, not per request. Every unlisted app/route/arm has zero traced survivors of all five types. All remaining enumerated objects were garbage; no heap graph or retained-byte claim is made.\n"
tables << "| Profile | String | Hash | Array | Proc | Other |\n|---|---:|---:|---:|---:|---:|"
profiles.select { _2.fetch("retained").positive? }.each do |id, p|
  tables << "| #{id} | #{%w[String Hash Array Proc other].map { p.fetch('types').fetch(_1, {}).fetch('retained', 0) }.join(' | ')} |"
end

%w[blog starter redprints pingcrm].each do |app|
  tables << "\n## #{app}: top 30 allocating file:line + class pairs\n\nEqual-weight mean across this app's measured routes/formats, **not a traffic mix**. Off selects the ranking; Default is the same callsite/class in the paired default process. Different classes on the same line are separate rows. Classifications and their exact mechanisms/certificates are defined above; `a/opaque` is deliberately not credited as removable. Full per-route counts are in the numeric export.\n"
  arms = %w[off default].to_h do |arm|
    set = profiles.select { |id, _| id.start_with?(app + "-") && id.end_with?("-" + arm) }.values
    sums = Hash.new(0.0)
    set.each { |p| p.fetch("callsites").each { |row| sums[row.values_at("file", "line", "class")] += row.fetch("allocated").fdiv(p.fetch("requests") * set.size) } }
    [arm, sums]
  end
  tables << "| Allocating file:line | Class | Off | Default | Class / mechanism |\n|---|---|---:|---:|---|"
  arms.fetch("off").sort_by { |key, count| [-count, key.to_s] }.first(30).each do |(file, line, klass), count|
    tables << "| `#{file}:#{line}` | `#{klass}` | #{format('%.2f', count)} | #{format('%.2f', arms.fetch('default').fetch([file, line, klass], 0))} | #{classification(file, line, klass, app)} |"
  end
end
files = profiles.values.flat_map { _1.fetch("callsites").map { |row| row.fetch("file") } }.uniq.sort
classes = profiles.values.flat_map { _1.fetch("callsites").map { |row| row.fetch("class") } }.uniq.sort
file_ids, class_ids = [files, classes].map { _1.each_with_index.to_h }
export = profiles.transform_values do |p|
  p.merge("callsites" => p.fetch("callsites").map do |row|
    [file_ids.fetch(row.fetch("file")), row.fetch("line"), class_ids.fetch(row.fetch("class")),
      row.fetch("type"), row.fetch("allocated"), row.fetch("retained")]
  end)
end
File.write(File.join(root, "docs/passes/allocations-results.json"), JSON.generate(schema_version: 1,
  callsite_columns: %w[file_index line class_index type allocated retained], files: files, classes: classes, profiles: export) + "\n")

# Optional LABEL=GROUP_OUTPUT_DIR arguments retain signed samples and decisive
# controls without duplicating every incidental Ruby GC statistic twice.
micros = ARGV.drop(1).to_h do |arg|
  label, directory = arg.split("=", 2)
  data = JSON.parse(File.read(File.join(directory, "samples.json")))
  samples = data.fetch("samples").map do |round|
    round.transform_values do |sample|
      sample.merge("windows" => sample.fetch("windows").map do |window|
        window.to_h do |key, value|
          value = value.slice("total_allocated_objects", "minor_gc_count", "major_gc_count") if %w[before after].include?(key)
          value = value.transform_values { _1.slice("heap_eden_slots", "slot_size") } if %w[pools_before pools_after].include?(key)
          [key, value]
        end
      end)
    end
  end
  [label, { metadata: data.except("samples", "workers"),
    workers: data.fetch("workers").transform_values { _1.except("windows") }, samples: samples,
    budget: JSON.parse(File.read(File.join(directory, "budgets.json"))),
    controls: JSON.parse(File.read(File.join(directory, "summary.json"))) }]
end
unless micros.empty?
  File.write(File.join(root, "docs/passes/allocations-micros.json"), JSON.generate(micros) + "\n")
end
doc = File.join(root, "docs/passes/allocations.md")
marker = "<!-- generated allocation tables -->"
header = File.read(doc).split(marker).first
File.write(doc, header + marker + "\n\n" + tables.join("\n") + "\n")
