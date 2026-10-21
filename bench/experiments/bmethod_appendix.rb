# frozen_string_literal: true

# Pack the raw research files named below. No app boot or request execution.
# ruby bmethod_appendix.rb RAW_DIRECTORY OUTPUT.json RECORDED_LOWRAIL_REVISION
require "json"
require "digest"
require "open3"

root = File.expand_path("../..", __dir__)
raw = File.realpath(ARGV.fetch(0))
tables = {strings: [], parameters: [], locations: [], shapes: [], ancestries: [], methods: []}
indexes = tables.transform_values { {} }
intern = lambda do |table, value|
  next nil if value.nil?
  key = JSON.generate(value)
  indexes.fetch(table)[key] ||= begin
    tables.fetch(table) << value
    tables.fetch(table).size - 1
  end
end
shape = lambda do |value|
  next nil unless value
  intern.call(:shapes, [intern.call(:strings, value["owner"]), intern.call(:locations, value["source_location"]),
    intern.call(:parameters, value["parameters"]), value["arity"], value["iseq_type"], intern.call(:strings, value["iseq_label"])])
end
method_row = lambda do |row|
  intern.call(:methods, [intern.call(:strings, row["holder"]), intern.call(:strings, row["name"]), shape.call(row["generated"]), shape.call(row["current"]),
    row["visibility"], intern.call(:ancestries, row["ancestors"].map { intern.call(:strings, _1) }), intern.call(:locations, row["definition_at"]),
    row["enum_generator"], row.fetch("later_definitions", []).map { shape.call(_1) },
    row["consumer_overrides"].map { |entry| [intern.call(:strings, entry["receiver"]), shape.call(entry["effective"]), entry["visibility"]] },
    intern.call(:strings, row["eval_sha256"]), row.fetch("replaced_on_holder")])
end
files = {blog: ["real-blog-r4", "blog-production"], fizzy: ["fizzy", "fizzy-production"],
  casa: ["casa", "casa-production"], writebook: ["writebook", "writebook-test"],
  codetriage: ["codetriage", "codetriage-test"], campfire: ["campfire", "campfire-test"],
  pingcrm: ["pingcrm", "pingcrm-test"], "redprints-cfp": ["redprints-cfp", "redprints-cfp-test"],
  "react-starter-kit": ["react-starter-kit", "react-starter-kit-test"]}
apps = files.to_h do |name, (directory, stem)|
  data = JSON.parse(File.read(File.join(raw, "#{stem}.json")))
  methods = data.delete("methods")
  data["raw_sha256"] = Digest::SHA256.file(File.join(raw, "#{stem}.json")).hexdigest
  data["method_ids"] = methods.map { method_row.call(_1) }
  data["static"] = JSON.parse(File.read(File.join(raw, "#{directory}-static.json")))
  data["revision"] = if name == :blog
    File.read(File.join(root, ".corpus/#{directory}/.lowrail-corpus-source")).strip
  else
    Open3.capture2("git", "-C", File.join(root, ".corpus", directory), "rev-parse", "HEAD").first.strip
  end
  data["families"] = methods.group_by { |row| row.dig("generated", "source_location", 0) }.map do |path, rows|
    {source: path, source_sha256: path && File.file?(path) ? Digest::SHA256.file(path).hexdigest : nil,
      entries: rows.size, bmethods: rows.count { _1.dig("generated", "iseq_type") == "block" },
      observed_define_method: rows.count { _1["definition_at"] }, eval_plain_def: rows.count { _1["eval_sha256"] },
      entries_with_consumer_overrides: rows.count { !_1["consumer_overrides"].empty? }}
  end.sort_by { -_1[:entries] }
  [name, data]
end
requests = %w[blog fizzy].to_h do |name|
  data = JSON.parse(File.read(File.join(raw, "#{name}-state/requests.json")))
  boot = JSON.parse(File.read(File.join(raw, "#{name}-state/boot.json")))
  authentication = name == "fizzy" ? data.shift(2) : []
  ranked = Hash.new(0)
  families = Hash.new(0)
  data.each_with_index do |request, index|
    request["phase"] = %w[cold warm warm_repeat][index / (name == "fizzy" ? 6 : 2)]
    request["total_bmethod_calls"] = request["calls"].sum { _1["count"] }
    request["calls"].each do |call|
      key = [call["holder"], call["name"], shape.call(call.reject { |key, _| %w[name holder count].include?(key) })]
      ranked[key] += call["count"]
      families[call["source_location"][0]] += call["count"]
      call["shape"] = key.last
      call.delete("source_location")
    end
  end
  [name, {boot_enums: boot["enums"], boot_counts: boot["counts"],
    authentication_statuses_excluded: authentication.map { _1["status"] }, requests: data,
    ranked: ranked.sort_by { |_, count| -count }.map { |(holder, name, shape), count| {holder: holder, name: name, shape: shape, calls: count} },
    families: families.sort_by { |_, count| -count }.map { |path, count| {source: path, calls: count} }}]
end
result = {schema: "lowrail-bmethod-census-v1", date: "2026-10-21", kind: "research_not_support_or_price",
  lowrail_revision: ARGV.fetch(2),
  packaging_revision: Open3.capture2("git", "-C", root, "rev-parse", "HEAD").first.strip,
  method_columns: %w[holder name generated_shape current_shape visibility ancestry definition_location enum_generator later_shapes consumer_overrides eval_sha256 replaced_on_holder],
  shape_columns: %w[owner location parameters arity iseq_type iseq_label],
  override_columns: %w[receiver effective_shape visibility],
  dictionary_fields: "holder/name/owner/receiver/iseq_label/eval_sha256 and ancestry members index strings; shape/ancestry/location/parameters fields index their respective tables. null means absent, never index zero.",
  identity_scope: "Anonymous owner labels are local to each app boot; request boots have separate labels. Shared table rows are structural compression, not cross-process identity claims.",
  request_harness_source: File.read(File.join(raw, "requests.rb")),
  census_script_sha256: Digest::SHA256.file(File.join(root, "bench/experiments/bmethod_census.rb")).hexdigest,
  sources_are_display_paths_not_load_control_normalization: true,
  apps: apps, requests: requests,
  micro: %w[interpreter yjit].to_h { [_1, JSON.parse(File.read(File.join(raw, "micro-#{_1}.json")))] },
  locations_probe: JSON.parse(File.read(File.join(raw, "locations.json"))),
  locations_probe_source: File.read(File.join(raw, "locations.rb")),
  real_enum_location_probe: JSON.parse(File.read(File.join(raw, "enum-locations.json"))),
  writebook_production_failure: "NoMethodError: undefined method sqlite3_production_warning= for class ActiveRecord::Base; config/environments/production.rb:66",
  excluded_attempts: ["Initial census observer invoked Module#name overrides (REXML/RuboCop) and Module#hash override (Kredis); corrected with bound Module#name and identity hashes, then all apps rerun.",
    "Initial optional-app loop had a wrong working-directory lock path / shared DATABASE_URL; discarded; final apps use independent DB configuration.",
    "Initial Fizzy command concatenated root paths from app cwd and did not start; corrected before census."]}
result.merge!(tables)
output = ARGV.fetch(1)
# Keep each dictionary/table entry on one line, rather than publishing 300 MB
# of repeated source paths, ancestry lists and inherited override shapes.
File.open(output, "w") do |file|
  file.puts "{"
  result.each_with_index do |(key, value), index|
    file.write "  #{JSON.generate(key)}: "
    if Array === value && value.size > 100
      file.puts "["
      value.each_with_index { |entry, i| file.puts "    #{JSON.generate(entry)}#{i == value.size - 1 ? '' : ','}" }
      file.write "  ]"
    else
      file.write JSON.generate(value)
    end
    file.puts(index == result.size - 1 ? "" : ",")
  end
  file.puts "}"
end
puts JSON.generate(output: output, bytes: File.size(output), tables: tables.transform_values(&:size))
