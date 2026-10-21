# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../fixtures/corpus/blog_production"

class BlogProductionTest < Minitest::Test
  def runs
    baseline = {"initial_effects" => {"articles" => [1, 2], "jobs" => []},
      "loads" => {"cold_boot" => {"load_events" => ["0 load Article", "1 hook active_record"]}},
      "features" => ["article.rb", "comment.rb"], "errors" => [],
      "scenarios" => BlogProduction::SCENARIOS.map { |scenario| {
        "id" => scenario.fetch("id"), "response" => {"status" => 200, "headers" => {"etag" => "literal"}, "body" => "<p>article</p>"},
        "sql" => [{"sql" => "SELECT * FROM articles WHERE id = ?", "binds" => [1]}, {"sql" => "SELECT * FROM comments", "binds" => []}],
        "effects" => {"articles" => [1, 2], "jobs" => [], "files" => {}}, "hits" => {}, "fallbacks" => {}} }}
    result = Array.new(3) { Marshal.load(Marshal.dump(baseline)) }
    result.last.fetch("scenarios").first["hits"] = {"18" => 2}
    result
  end

  def test_exact_comparison_rejects_changed_bind_response_effect_and_real_load_order
    assert_equal "equivalent_for_executed_scenarios", BlogProduction.compare(runs).fetch("status")
    changes = {
      "sql" => ->(run) { run.fetch("scenarios").first.fetch("sql").first["binds"] = [2] },
      "response" => ->(run) { run.fetch("scenarios").first.fetch("response")["body"] = "<p>wrong article</p>" },
      "response_header" => ->(run) { run.fetch("scenarios").first.fetch("response").fetch("headers")["etag"] = "different" },
      "effects" => ->(run) { run.fetch("scenarios").first.fetch("effects")["jobs"] = ["duplicate broadcast"] },
      "sql_order" => ->(run) { run.fetch("scenarios").first.fetch("sql").reverse! },
      "loads" => ->(run) { run.fetch("loads").fetch("cold_boot")["load_events"] = ["0 hook active_record", "1 load Article"] }
    }
    changes.each do |field, change|
      records = runs
      change.call(records.last)
      report = BlogProduction.compare(records)
      assert_equal "rejected", report.fetch("status"), field
      assert_empty report.fetch("differences").fetch("off_control")
      assert report.fetch("differences").fetch("off_on").any?, field
    end
  end

  def test_off_off_entropy_is_reported_as_rejected_control_not_lowrail_divergence
    records = runs
    records[1].fetch("scenarios").first.fetch("response")["body"] = "different CSRF token"
    report = BlogProduction.compare(records)
    assert_equal "rejected_off_control", report.fetch("status")
    assert_equal ["ArticlesControllerTest#test_should_get_index:response"], report.fetch("differences").fetch("off_control")
    assert_empty report.fetch("differences").fetch("off_on")
    assert_equal ["18"], report.fetch("hit_units")
  end

  def test_zero_hits_missing_scenarios_and_capture_errors_cannot_pass
    records = runs
    records.last.fetch("scenarios").first["hits"] = {}
    assert_equal "unexercised", BlogProduction.compare(records).fetch("status")
    records.last.fetch("scenarios").pop
    assert_raises(RuntimeError) { BlogProduction.compare(records) }
    records = runs
    records.last["errors"] = ["unavailable adapter bind values (Proc)"]
    assert_equal "rejected", BlogProduction.compare(records).fetch("status")
    records = runs
    records.each { _1["loads"] = {"cold_boot" => {"errors" => ["capture failed"]}} }
    assert_equal "rejected", BlogProduction.compare(records).fetch("status")
  end

  def test_value_capture_keeps_encoding_float_bits_and_unknowns_fail_closed
    left = BlogProduction.value("\xFF".b)
    right = BlogProduction.value("\xFF".b.force_encoding("ISO-8859-1"))
    assert_equal "/w==", left.fetch("base64")
    refute_equal left, right
    refute_equal BlogProduction.value(-0.0), BlogProduction.value(0.0)
    assert_raises(RuntimeError) { BlogProduction.value(Object.new) }
  end
end
