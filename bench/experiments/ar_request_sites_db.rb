# frozen_string_literal: true

# Read-only, complete four-database audit of the existing typed snapshot.
# Never alter the raw DB hash/SQL gate. Each exclusion needs current off/off
# evidence. Primary/queue/cable and app cache key/value bytes stay exact.
require "base64"
require "json"
require "digest"

module DirectSiteDB
  EXCLUSIONS = {
    "cache.solid_cache_entries.created_at" => "SQLite STRFTIME(..., 'NOW') cache insertion timestamp; current off/off proof required"
  }.freeze
  INTERNAL_KEY = "__solid_cache_entry_size_moving_average_estimates".b.freeze
  module_function

  def digest(value) = Digest::SHA256.hexdigest(JSON.generate(value))
  def string(value) = Base64.strict_decode64(value.fetch("base64"))

  def capture(databases)
    columns = {}
    canonical = databases.to_h do |database, contents|
      tables = contents.fetch("tables").to_h do |table, data|
        header, *rows = data
        names = header.map { string(_1) }
        kept = names.each_index.reject do |index|
          key = "#{database}.#{table}.#{names[index]}"
          columns[key] = digest(rows.map { _1[index] })
          EXCLUSIONS.key?(key)
        end
        [table, {"header" => kept.map { header[_1] }, "rows" => rows.map { |row| kept.map { row[_1] } }}]
      end
      [database, contents.merge("tables" => tables)]
    end
    {"raw_sha256" => digest(databases), "comparison_sha256" => digest(canonical),
      "raw_databases" => databases.transform_values { digest(_1) },
      "cache_boundary" => cache_boundary(databases.fetch("cache")),
      "columns" => columns,
      "inventory" => databases.transform_values { |db| {"schema_sha256" => digest(db.fetch("schema")),
        "tables" => db.fetch("tables").transform_values { |rows| rows.size - 1 }} }}
  end

  def cache_boundary(database)
    tables = database.fetch("tables")
    header, *rows = tables.fetch("solid_cache_entries")
    names = header.map { string(_1) }
    key_index, value_index = %w[key value].map { names.index(_1) }
    internal, app = rows.partition { string(_1.fetch(key_index)) == INTERNAL_KEY }
    decoded = internal.map do |row|
      payload = string(row.fetch(value_index))
      raise "unrecognized store estimate" unless payload.match?(/\A\d+(?:\|\d+){0,49}\z/)
      {"estimates_bytes" => payload.split("|").map { Integer(_1) },
        "row_sha256" => digest(row), "byte_size" => row.fetch(names.index("byte_size")).fetch("value")}
    end
    {"schema_sha256" => digest(database.fetch("schema")),
      "app_key_values_sha256" => digest(app.map { [_1.fetch(key_index), _1.fetch(value_index)] }.sort_by { _1.first.fetch("base64") }),
      "app_entry_count" => app.size, "internal" => decoded,
      "metadata_sha256" => digest(tables.except("solid_cache_entries", "sqlite_sequence")),
      "sequence_sha256" => digest(tables.fetch("sqlite_sequence")),
      "current_total_byte_size" => rows.sum { _1.fetch(names.index("byte_size")).fetch("value") }}
  end

  def compare(workers)
    off_a, on, off_b = workers.values_at("off_a", "on", "off_b")
    seen_noise = []
    checks = off_a.fetch("cases").to_h do |name, seeds|
      [name, seeds.to_h do |seed, _|
        snapshots = [off_a, on, off_b].map { _1.fetch("cases").fetch(name).fetch(seed).fetch("db_audit") }
        a, treatment, b = snapshots
        keys = a.fetch("columns").keys
        noise = keys.select { a.fetch("columns").fetch(_1) != b.fetch("columns").fetch(_1) }
        effect = keys.select { a.fetch("columns").fetch(_1) != treatment.fetch("columns").fetch(_1) }
        seen_noise |= noise
        same_inventory = snapshots.map { _1.fetch("inventory") }.uniq.one?
        same = snapshots.map { _1.fetch("comparison_sha256") }.uniq.one?
        covered = (noise - EXCLUSIONS.keys).empty? && (effect - noise).empty?
        complete_databases = %w[primary queue cable].to_h do |database|
          [database, snapshots.map { _1.fetch("raw_databases").fetch(database) }.uniq.one?]
        end
        cache = snapshots.map { _1.fetch("cache_boundary") }
        cache_equal = cache.map { _1.slice("schema_sha256", "app_key_values_sha256", "app_entry_count", "metadata_sha256") }.uniq.one?
        [seed, {"passed" => same && same_inventory && covered,
          "split_certificate" => {"passed" => complete_databases.values.all? && cache_equal,
            "complete_databases_no_exclusions" => complete_databases, "cache_app_keys_values_exact" => cache_equal},
          "complete_inventory_equal" => same_inventory, "nonexcluded_state_equal" => same,
          "off_off_differing_columns" => noise, "off_on_differing_columns" => effect,
          "all_on_differences_also_off_off" => (effect - noise).empty?}]
      end]
    end
    {"passed_with_declared_exclusions" => checks.values.all? { _1.values.all? { |row| row.fetch("passed") } },
      "split_certificate_passed" => checks.values.all? { _1.values.all? { |row| row.fetch("split_certificate").fetch("passed") } },
      "store_internal_boundary" => "Only #{INTERNAL_KEY}; raw decoded size estimates, row presence and SQLite sequence effects retained separately; not noise or deterministic full-cache equivalence",
      "exclusions" => EXCLUSIONS.select { |column, _| seen_noise.include?(column) },
      "unused_candidates" => EXCLUSIONS.keys - seen_noise, "checks" => checks}
  end
end

# Publish only hashes, counts and the decoded store-internal estimate. Raw SQL,
# cache payloads, cookies and entropy traces remain in the private receipts.
if $PROGRAM_NAME == __FILE__
  abort "usage: ruby ar_request_sites_db.rb SEED_0_RESULT SEED_1_RESULT EXPORT" unless ARGV.size == 3
  inputs = ARGV.first(2)
  runs = inputs.map do |path|
    result = JSON.parse(File.read(path))
    audit = DirectSiteDB.compare(result.fetch("workers"))
    raise "DB audit differs from receipt" unless audit == result.fetch("db_audit")
    raise "declared DB comparison failed" unless audit.fetch("passed_with_declared_exclusions")
    result.fetch("workers").each_value do |worker|
      raise "YJIT inactive" unless worker.fetch("yjit")
      worker["warm_entropy"] = worker.fetch("warm_entropy").except("trace", "clock_reads", "wall_clock_reads")
      worker.fetch("cases").each_value do |seeds|
        seeds.each_value do |row|
          row.delete("sql_trace")
          row.delete("sql_capture")
          row["evidence"] = row.fetch("evidence").except("trace", "clock_reads", "wall_clock_reads")
          row.fetch("db_audit")["columns"].select! { |column, _| DirectSiteDB::EXCLUSIONS.key?(column) }
        end
      end
    end
    {"receipt_sha256" => Digest::SHA256.file(path).hexdigest, "result" => result}
  end
  pins = [__FILE__, File.join(__dir__, "ar_request_sites.rb"), File.join(__dir__, "ar_request_sites_check.rb")]
  export = {"format" => 1, "scope" => "two seeded, forked, untimed DirectSite DB admission controls; not production admission",
    "sources" => pins.to_h { [File.basename(_1), Digest::SHA256.file(_1).hexdigest] }, "runs" => runs}
  File.write(ARGV.last, JSON.pretty_generate(export) + "\n")
end
