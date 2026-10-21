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
        "events" => [{"phase" => "start", "name" => "render_template.action_view"}, {"phase" => "finish", "name" => "render_template.action_view"}],
        "entropy_trace" => nil,
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
      "events" => ->(run) { run.fetch("scenarios").first.fetch("events").reverse! },
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

  def test_companions_keep_exact_body_sql_events_and_entropy_order_despite_recorded_real_clock
    records = runs
    records.each_with_index do |run, index|
      run["entropy_seed"] = 1
      run.fetch("scenarios").each do |scenario|
        scenario["entropy_trace"] = [{"site" => "csrf_mask", "sha256" => "same-controlled-bytes"}]
        scenario["clock_observations"] = [{"real" => 42.5 + index, "pinned" => 1000.0}]
      end
    end
    assert_equal "equivalent_for_executed_scenarios", BlogProduction.compare(records).fetch("status")
    %w[response sql events entropy_trace].each do |field|
      changed = Marshal.load(Marshal.dump(records))
      changed.last.fetch("scenarios").first[field] = "real mismatch, not excused by entropy policy"
      assert_equal "rejected", BlogProduction.compare(changed).fetch("status"), field
    end
  end

  def test_entropy_pins_stop_applying_when_source_or_lock_changes
    Dir.mktmpdir do |app|
      FileUtils.mkdir_p(File.join(app, "app"))
      File.write(File.join(app, "app/article.rb"), "class Article; end")
      lock = File.join(app, "Gemfile.lock")
      File.write(lock, "pinned lock")
      policy = {"app_source_sha256" => BlogProduction::Entropy.source_pin(app),
        "lock_sha256" => Digest::SHA256.file(lock).hexdigest, "ruby_version" => RUBY_VERSION, "runtime_sources" => {}}
      assert BlogProduction::Entropy.validate(app, policy: policy).fetch("active")
      File.write(lock, "new lock")
      report = BlogProduction::Entropy.validate(app, policy: policy)
      refute report.fetch("active")
      assert_equal "lockfile pin mismatch", report.fetch("reason")
      File.write(File.join(app, "app/article.rb"), "class Different; end")
      assert_equal "app source pin mismatch", BlogProduction::Entropy.validate(app, policy: policy).fetch("reason")
      refute BlogProduction::Entropy.validate(app, policy: {}).fetch("active")
    end
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
