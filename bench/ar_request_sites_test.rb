# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../fixtures/corpus/blog_production"
require_relative "experiments/ar_request_sites_db"
require_relative "experiments/jit_guards_export"

class DirectSiteDBTest < Minitest::Test
  def snapshot(created:, counter: 3, primary: 17, estimate: false, extra_cache_column: false)
    value = BlogProduction.method(:value)
    cache = [["rowid", "id", "key", "value", "byte_size", "created_at"],
      [1, 1, "production:rate-limit:sessions".b, Marshal.dump(counter), 189, created]]
    cache << [2, 2, DirectSiteDB::INTERNAL_KEY, "189".b, 192, created] if estimate
    if extra_cache_column
      cache.first << "on_only_column"
      cache.drop(1).each { _1 << 923 }
    end
    tables = {"sqlite_sequence" => value.call([["name", "seq"], ["solid_cache_entries", estimate ? 2 : 1]]),
      "solid_cache_entries" => value.call(cache)}
    state = %w[primary queue cable].to_h do |name|
      [name, {"schema" => value.call(["unchanged schema"]),
        "tables" => {"records" => value.call([["id"], [name == "primary" ? primary : 5]])}}]
    end
    state["cache"] = {"schema" => value.call(["unchanged cache schema"]), "tables" => tables}
    DirectSiteDB.capture(state)
  end

  def compare(a, on, b)
    workers = %w[off_a on off_b].zip([a, on, b]).to_h.transform_values do |snapshot|
      {"cases" => {"baseline" => {"0" => {"db_audit" => snapshot}}}}
    end
    DirectSiteDB.compare(workers)
  end

  def test_only_proved_sqlite_timestamps_and_the_named_internal_boundary_are_allowed
    a = snapshot(created: "2026-10-22 12:01:02.003")
    b = snapshot(created: "2026-10-22 12:02:03.004")
    control = compare(a, b, b)
    assert control.fetch("passed_with_declared_exclusions")
    assert control.fetch("split_certificate_passed")
    assert_equal ["cache.solid_cache_entries.created_at"], control.fetch("exclusions").keys

    [snapshot(created: "different", counter: 7), snapshot(created: "different", primary: 91)].each do |changed|
      result = compare(a, changed, b)
      refute result.fetch("passed_with_declared_exclusions")
      refute result.fetch("split_certificate_passed")
    end

    added_column = compare(a, snapshot(created: "different", extra_cache_column: true), b)
    refute added_column.fetch("passed_with_declared_exclusions"), "canonical headers reject on-only columns"
    refute added_column.fetch("split_certificate_passed"), "split header check is independent of the schema string"

    internal = snapshot(created: "different", estimate: true)
    boundary = compare(a, internal, b)
    refute boundary.fetch("passed_with_declared_exclusions"), "row presence is not timestamp noise"
    assert boundary.fetch("split_certificate_passed"), "only the explicitly named store-internal boundary permits this"
    assert_equal [189], internal.fetch("cache_boundary").fetch("internal").first.fetch("estimates_bytes")
    assert_equal 381, internal.fetch("cache_boundary").fetch("current_total_byte_size")
  end
end

class JitGuardsExportTest < Minitest::Test
  def test_compaction_preserves_measurements_and_recoverable_provenance
    Dir.mktmpdir do |directory|
      path = File.join(directory, "receipt.json")
      measurement = {"rps" => 519.25, "errors" => 0, "pins" => true,
        "windows" => [{"passed" => true, "instructions" => 37_722_639}, {"passed" => false, "instructions" => 38_000_091}]}
      inventory = {"primary" => {"tables" => {"sessions" => 4}}}
      small = {"passed" => true, "errors" => []}
      bulky = {"passed" => false, "steps" => ["record" * 500]}
      original = {"measurement" => measurement, "pins" => {"runtime.rb" => "historical-source-hash", "artifact/generated/a.rb" => "generated-hash"},
        "interpreter" => {"protocol" => {"source_sha" => "historical-ir-commit"}},
        "rps" => {"measured_source" => "historical-rps-commit"},
        "workflow" => small, "coverage" => {"workflow" => bulky},
        "trace" => [{"caller" => "/private/machine/path"}],
        "snapshots" => [{"inventory" => inventory}, {"inventory" => inventory}]}
      bytes = JSON.generate(original)
      File.write(path, bytes)
      JitGuardsExport.publish(path, "original-commit")
      exported = JSON.parse(File.read(path))
      assert_equal measurement, exported.fetch("measurement")
      assert_equal "historical-source-hash", exported.fetch("pins").fetch("runtime.rb")
      assert_equal({"interpreter" => "historical-ir-commit", "rps" => "historical-rps-commit"}, exported.fetch("measurement_commits"))
      assert_equal small, exported.fetch("workflow")
      assert_equal Digest::SHA256.hexdigest(JSON.generate(bulky)), exported.fetch("coverage").fetch("workflow").fetch("sha256")
      assert_equal 1, exported.fetch("pins").fetch("omitted_generated_catalog").fetch("count")
      assert_equal Digest::SHA256.hexdigest(JSON.generate([["artifact/generated/a.rb", "generated-hash"]])),
        exported.fetch("pins").fetch("omitted_generated_catalog").fetch("sha256")
      assert_equal 1, exported.fetch("trace").fetch("count")
      assert_equal "original-commit", exported.fetch("original_export").fetch("commit")
      assert_equal Digest::SHA256.hexdigest(bytes), exported.fetch("original_export").fetch("sha256")
      assert_equal 1, exported.fetch("inventories").size
      exported.fetch("snapshots").each do |row|
        assert_equal inventory, exported.fetch("inventories").fetch(row.fetch("inventory_sha256"))
      end
    end
  end

  def test_control_publication_keeps_the_collector_shape_without_private_sql
    Dir.mktmpdir do |directory|
      input, output = %w[private.json public.json].map { File.join(directory, _1) }
      counts = {"bucket:hit" => 2, "bucket:fallback" => 0}
      row = {"status" => 200, "counts_delta" => counts, "sql_trace" => ["private bind"], "sql_capture" => ["private SQL"],
        "db_audit" => {"columns" => {"cache.solid_cache_entries.created_at" => "clock", "primary.secret" => "other hash"},
          "inventory" => {"primary" => {"tables" => {"sessions" => 3}}}}}
      bytes = JSON.generate("passed" => false, "response_sql_certificate_passed" => false,
        "workers" => {"on" => {"cases" => {"transitive_scope" => {"0" => row}}}})
      File.write(input, bytes)
      JitGuardsExport.publish_control(input, output)
      report = JSON.parse(File.read(output))
      projected = report.fetch("workers").fetch("on").fetch("cases").fetch("transitive_scope").fetch("0")
      assert_equal 200, projected.fetch("status")
      assert_equal counts, projected.fetch("counts_delta")
      refute projected.key?("sql_trace")
      refute projected.key?("sql_capture")
      assert_equal({"cache.solid_cache_entries.created_at" => "clock"}, projected.fetch("db_audit").fetch("columns"))
      refute report.fetch("passed")
      refute report.fetch("response_sql_certificate_passed")
      assert_equal Digest::SHA256.hexdigest(bytes), report.fetch("replay_receipt_sha256")
      assert_equal bytes, File.read(input)
    end
  end
end
