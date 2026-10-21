# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../fixtures/corpus/blog_production"

class BlogProductionTest < Minitest::Test
  include LowrailTest

  def test_cold_sealed_admission_does_not_prepare_the_app
    skip "sealed blog cold witness requires Ruby 4.0.7 (running #{RUBY_VERSION})" unless RUBY_VERSION == "4.0.7"
    source = File.join(CORPUS_ROOT, "real-blog-r4")
    missing_prerequisite "no #{source} (see script/corpus)" unless File.file?(File.join(source, "config/environment.rb"))
    realpath_tmpdir do |dir|
      output = File.join(dir, "cold")
      capture_io { BlogProduction.run(source, output, entropy_companions: true, cli: lowrail_cli) }
      report = JSON.parse(File.read(File.join(output, "report.json")))
      assert_equal "rejected_off_control", report.fetch("raw_status"), "raw entropy rejection is retained"
      report.fetch("entropy_companions").each do |companion|
        records = companion.fetch("workers").map { JSON.parse(File.read(File.join(output, _1))) }
        baseline = records.first
        records.each do |record|
          assert_empty record.fetch("errors")
          assert_empty record.fetch("boot_sql"), "no primary/cache/queue/cable probes before the app's requests"
          assert_equal baseline.fetch("cold_witness"), record.fetch("cold_witness")
          assert_equal baseline.fetch("exit_effects"), record.fetch("exit_effects"), "persisted state read after worker exit"
          features = record.fetch("cold_witness").fetch("features")
          assert_equal({"api_loaded" => false, "objspace" => []}, features.slice("api_loaded", "objspace"))
          %w[Object Kernel BasicObject].each do |holder|
            assert_includes features.fetch("holder_ancestry").keys, holder
            assert_includes features.fetch("holder_ancestry").fetch(holder), holder
          end
          after = record.fetch("cold_witness").fetch("after_requests")
          # Natural rendering may create the cached view and tag classes. It
          # must not add an off/on chain difference; compare like stages.
          assert_equal baseline.fetch("cold_witness").fetch("after_requests"), after
          assert_equal features.slice("api_loaded", "objspace"), after.slice("api_loaded", "objspace")
          assert_equal "Lowrail::FormScaffold::Variant", features.fetch("form_seam").fetch("owner")
          seams = record.fetch("cold_witness").fetch("natural_form_seams")
          assert_equal 1, seams.size
          assert_equal "Lowrail::FormScaffold::Variant", seams.first.fetch("bound_owner")
          assert_equal features.fetch("form_seam").fetch("source_location"), seams.first.fetch("instance_source_location")
          assert_equal %w[early_controller early_eager late_eager late_controller].sort,
            record.fetch("cold_witness").fetch("callbacks").map(&:first).sort
          assert_equal [14, 2], record.fetch("scenarios").map { _1.fetch("sql").size }
          assert_equal [200, 200], record.fetch("scenarios").map { _1.fetch("response").fetch("status") }
          assert record.fetch("scenarios").flat_map { _1.fetch("sql") }.all? { _1.fetch("database") == "primary" }
          baseline.fetch("scenarios").zip(record.fetch("scenarios")).each do |off, other|
            %w[response sql effects events].each { |field| assert_equal off.fetch(field), other.fetch(field), field }
          end
        end
        on = records.last
        assert_nil on.fetch("refusals").fetch("Lowrail::Sealed")
        assert_nil on.fetch("refusals").fetch("Lowrail::FormScaffold")
        form = report.fetch("units").find { _1.fetch("pass") == "sealed/form_scaffold" }
        link = report.fetch("units").find { _1.fetch("pass") == "sealed/link_to" }
        refute_nil form, "build-time form certification remains intact"
        refute_nil link
        form_id, link_id = [form, link].map { _1.fetch("id").to_s }
        # The first natural show is still original. This cold slice alone is
        # not fast-path coverage; the 192-pair and threaded witnesses cover it.
        assert on.fetch("scenarios").all? { _1.fetch("hits").fetch(form_id, 0).zero? && _1.fetch("fallbacks").fetch(form_id, 0).zero? }
        refute on.fetch("unit_refusals").key?(form_id)
        assert_equal [5, 2], on.fetch("scenarios").map { _1.fetch("hits").fetch(link_id, 0) }
        assert on.fetch("scenarios").all? { _1.fetch("fallbacks").fetch(link_id, 0).zero? }
        refute on.fetch("unit_refusals").key?(link_id)
      end
      assert_equal 2, report.fetch("entropy_companions").size, "both declared seeds must run"
      %w[article_create csrf_missing csrf_invalid].each do |key|
        scenario = BlogProduction::Breadth::CASES.find { _1.fetch("key") == key }
        records = %w[off1 off2 on].map do |arm|
          app = File.join(output, "app")
          FileUtils.rm_rf(File.join(app, "storage"))
          FileUtils.cp_r(File.join(output, "seed"), File.join(app, "storage"))
          FileUtils.rm_rf(File.join(app, "tmp"))
          destination = File.join(output, "#{key}-#{arm}.json")
          out, err, status = ruby("--yjit", BlogProduction::SCRIPT, "worker", "case:#{key}", destination, "0",
            chdir: app, env: {"RAILS_ENV" => "production", "RACK_ENV" => "production", "LOWRAIL_ROOT" => app,
              "LOWRAIL" => arm == "on" ? "1" : "0", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "",
              "RAILS_LOG_LEVEL" => "fatal", "SECRET_KEY_BASE_DUMMY" => nil, "SECRET_KEY_BASE" => BlogProduction::Entropy::SECRET})
          assert status.success?, "#{key}/#{arm}: #{err}\n#{out}"
          JSON.parse(File.read(destination))
        end
        comparison = BlogProduction.compare(records, scenarios: [scenario])
        assert_empty comparison.fetch("differences").fetch("off_control"), key
        assert_empty comparison.fetch("differences").fetch("off_on"), key
        assert_empty comparison.fetch("capture_errors"), key
        assert records.all? { BlogProduction.oracles(_1, "unused").all? { |check| check.fetch("passed") } }, key
        if key == "article_create"
          assert_equal "equivalent_for_executed_scenarios", comparison.fetch("status")
          assert_equal [200, 302, 200, 200], records.last.fetch("scenarios").first.fetch("response").fetch("steps").map { _1.fetch("response").fetch("status") }
          assert records.last.fetch("scenarios").first.fetch("sql").any? { _1.fetch("database") == "queue" }, "after_commit broadcast persisted"
        end
      end
    end
  end

  def runs
    baseline = {"initial_effects" => {"articles" => [1, 2], "jobs" => []},
      "boot_sql" => [], "cold_witness" => {"hooks" => ["before_eager_load"], "features" => {"api_loaded" => false, "objspace" => []}},
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
      "boot_sql" => ->(run) { run.fetch("boot_sql") << {"database" => "queue", "sql" => "SELECT sqlite_version(*)"} },
      "late_sql" => ->(run) { run["late_sql"] = [{"database" => "cable", "sql" => "INSERT INTO solid_cable_messages VALUES ('late')"}] },
      "sql_stream" => ->(run) { run["sql_stream"] = [{"phase" => "post_scenario", "thread" => "other"}] },
      "exit_effects" => ->(run) { run["exit_effects"] = {"cable" => ["persisted after report"]} },
      "cold_hook" => ->(run) { run.fetch("cold_witness").fetch("hooks") << "before_eager_load" },
      "cold_feature" => ->(run) { run.fetch("cold_witness").fetch("features")["api_loaded"] = true },
      "cold_ancestry" => ->(run) { run.fetch("cold_witness").fetch("features")["holder_ancestry"] = {"Object" => %w[Object Kernel Lowrail::Guard::ObjectHooks BasicObject]} },
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

  def test_write_workflows_compare_intermediate_redirects_flash_and_queue_effects
    records = runs
    records.each do |run|
      run.fetch("scenarios").first["response"] = {"completed" => true,
        "checks" => [{"name" => "created once", "passed" => true}], "steps" => [
          {"kind" => "request", "response" => {"status" => 302, "headers" => {"location" => "/articles/3", "set-cookie" => "exact-cookie"}, "body" => ""},
            "flash" => {"notice" => "created"}, "effects" => {"articles" => [1, 2, 3], "queue" => [{"job_id" => "exact-id", "arguments" => "exact"}]}},
          {"kind" => "request", "response" => {"status" => 200, "headers" => {}, "body" => "Created"}, "flash" => {"notice" => "created"}}
        ]}
      run["cold_cases"] = [{"id" => "write", "boot_sql" => [], "initial_effects" => {"articles" => [1, 2]}}]
    end
    assert_equal "equivalent_for_executed_scenarios", BlogProduction.compare(records).fetch("status")
    changes = [
      ->(run) { run.fetch("scenarios").first.fetch("response").fetch("steps").first.fetch("response")["status"] = 303 },
      ->(run) { run.fetch("scenarios").first.fetch("response").fetch("steps").first.fetch("response").fetch("headers")["set-cookie"] = "different" },
      ->(run) { run.fetch("scenarios").first.fetch("response").fetch("steps").first.fetch("flash")["notice"] = "wrong flash" },
      ->(run) { run.fetch("scenarios").first.fetch("response").fetch("steps").first.fetch("effects").fetch("queue").clear },
      ->(run) { run.fetch("cold_cases").first.fetch("initial_effects")["articles"] = [1] }
    ]
    changes.each do |change|
      altered = Marshal.load(Marshal.dump(records))
      change.call(altered.last)
      assert_equal "rejected", BlogProduction.compare(altered).fetch("status")
    end
    incomplete = Marshal.load(Marshal.dump(records))
    incomplete.last.fetch("scenarios").first.fetch("response")["completed"] = false
    probe = {"scenarios" => [incomplete.last.fetch("scenarios").first]}
    refute BlogProduction.oracles(probe, "unused").first.fetch("passed"), "partial checks cannot claim completed source coverage"
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
