# frozen_string_literal: true

require "minitest/autorun"
require_relative "../fixtures/corpus/blog_production"
require_relative "experiments/ar_request_sites_db"

class DirectSiteDBTest < Minitest::Test
  def snapshot(created:, counter: 3, primary: 17, estimate: false)
    value = BlogProduction.method(:value)
    cache = [["rowid", "id", "key", "value", "byte_size", "created_at"],
      [1, 1, "production:rate-limit:sessions".b, Marshal.dump(counter), 189, created]]
    cache << [2, 2, DirectSiteDB::INTERNAL_KEY, "189".b, 192, created] if estimate
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

    internal = snapshot(created: "different", estimate: true)
    boundary = compare(a, internal, b)
    refute boundary.fetch("passed_with_declared_exclusions"), "row presence is not timestamp noise"
    assert boundary.fetch("split_certificate_passed"), "only the explicitly named store-internal boundary permits this"
    assert_equal [189], internal.fetch("cache_boundary").fetch("internal").first.fetch("estimates_bytes")
    assert_equal 381, internal.fetch("cache_boundary").fetch("current_total_byte_size")
  end
end
