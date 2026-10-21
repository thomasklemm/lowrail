# frozen_string_literal: true

require "minitest/autorun"
load File.expand_path("../script/rps", __dir__)

class NativeBenchTest < Minitest::Test
  def test_screen_checks_actual_responses_both_seeds_every_round_and_control_evidence
    response = Struct.new(:status, :body, :headers)
    workers = 3.times.flat_map do |round|
      NativeBench::ARMS.map do |arm|
        {"round" => round, "arm" => arm, "coverage" => false, "exact" => {"GET /x" =>
          [0, 1].to_h { |seed| [seed.to_s, NativeBench.response_digest(response.new(200, "seed#{seed}", {"a" => "b"})).merge("evidence" => {"passed" => true})] }}}
      end
    end
    checks = -> { NativeScreen.exact_checks(workers).fetch("GET /x").values.map { _1.fetch("passed") } }
    assert_equal [true, true], checks.call
    last = workers.last.fetch("exact").fetch("GET /x").fetch("1")
    %w[status body_sha256 headers_sha256].each do |field|
      original = last.fetch(field)
      last[field] = "changed"
      assert_equal [true, false], checks.call, field
      last[field] = original
    end
    last.fetch("evidence")["passed"] = false
    assert_equal [true, false], checks.call
    assert_equal({"hits" => {"a" => 3, "b" => 0}},
      NativeScreen.counter_delta({"hits" => {"a" => 4}}, {"hits" => {"a" => 7, "b" => 0}}))
  end

  def test_report_uses_paired_rounds_and_retains_noise_and_zero_gc
    # Different baseline scales distinguish mean paired ratios from a ratio
    # of pooled means. Integer RSS also catches accidental integer division.
    workers = 6.times.flat_map do |round|
      %w[off_a off_b on].map do |arm|
        baseline = round.even? ? 100 : 400
        value = case arm
        when "off_a" then baseline
        when "off_b" then baseline * (round.even? ? 1.02 : 0.98)
        else baseline * (round.even? ? 0.8 : 0.9)
        end
        {"arm" => arm, "coverage" => false, "boot_ms" => value,
          "routes" => {"GET /example" => {"median_us" => value, "p90_us" => value * 2,
            "throughput_rps" => 1_000_000.0 / value, "allocations_per_request" => value,
            "gc_ms_per_request" => 0, "rss_after_kib" => {"VmRSS" => value.to_i}}}}
      end
    end
    workers << {"coverage" => true} # Must not enter any estimate.
    result = NativeBench.summarize(workers).fetch("GET /example")
    %w[median_us p90_us allocations_per_request boot_ms rss_kib].each do |metric|
      row = result.fetch(metric)
      assert_in_delta(-15, row.fetch("on_off").fetch("delta_pct"), 1e-10)
      assert_in_delta(0, row.fetch("aa").fetch("delta_pct"), 1e-10)
      assert_equal 6, row.fetch("on_off").fetch("round_deltas_pct").size
      assert_operator row.fetch("aa_noise_floor_pct"), :>, 0
      assert_equal "lower_than_noise_floor", row.fetch("direction")
    end
    assert_equal "unresolved_zero_baseline", result.fetch("gc_ms_per_request").fetch("direction")
    assert_equal [0, 0, 0, 0, 0, 0], result.fetch("gc_ms_per_request").fetch("on_off").fetch("absolute_round_deltas")
    workers.first.fetch("routes").fetch("GET /example").fetch("rss_after_kib")["VmRSS"] += 1
    rss = NativeBench.summarize(workers).fetch("GET /example").fetch("rss_kib")
    assert_in_delta 250 + 1.0 / 6, rss.fetch("arm_means").fetch("off_a"), 1e-10
  end

  def test_http_summary_pairs_rounds_and_exact_gate_includes_login_and_both_seeds
    rows = 3.times.flat_map do |round|
      %w[off_a on off_b].map do |arm|
        base = [100, 1000, 250][round]
        rate = base * {"off_a" => 1, "off_b" => 1.01, "on" => 1.2}.fetch(arm)
        samples = [0, 1].to_h do |seed|
          response = {"status" => 200, "body_sha256" => "body-#{seed}", "headers_sha256" => "headers",
            "evidence" => {"passed" => true}}
          [seed.to_s, response.merge("workflow" => {"login" => response.dup, "route" => response.dup})]
        end
        {"arm" => arm, "round" => round, "samples" => samples,
          "warmup" => {"errors" => 0}, "timed" => {"rps" => rate, "errors" => 0,
            "latency_ms" => {"p50" => 1, "p90" => 2, "p99" => 4}}}
      end
    end
    summary = NativeRps.summary(rows)
    assert_in_delta 1, summary.fetch("aa").fetch("delta_pct"), 1e-10
    assert_in_delta 20, summary.fetch("on_off").fetch("delta_pct"), 1e-10
    assert_equal 300, summary.fetch("median_rps").fetch("on")
    assert_equal({"p50" => 1, "p90" => 2, "p99" => 4}, summary.fetch("median_latency_ms").fetch("off_b"))
    assert NativeRps.exact_checks(rows).values.all? { _1.fetch("passed") }
    login = rows.last.fetch("samples").fetch("1").fetch("workflow").fetch("login")
    login["headers_sha256"] = "different cookie"
    assert_equal [true, false], NativeRps.exact_checks(rows).values.map { _1.fetch("passed") }
    login["headers_sha256"] = "headers"
    login.fetch("evidence")["passed"] = false
    refute NativeRps.exact_checks(rows).fetch("1").fetch("passed")
    login.fetch("evidence")["passed"] = true
    workflow = rows.last.fetch("samples").fetch("1").fetch("workflow")
    route = workflow.delete("route")
    refute NativeRps.exact_checks(rows).fetch("1").fetch("passed"), "missing route must fail"
    workflow["different-route"] = route
    refute NativeRps.exact_checks(rows).fetch("1").fetch("passed"), "replaced route must fail"
    rows.first.fetch("warmup")["errors"] = 3
    rows.last.fetch("timed")["errors"] = 2
    assert_equal 5, NativeRps.summary(rows).fetch("errors")
  end

  def test_http_metrics_are_untimed_process_snapshots_not_app_responses
    app = ->(env) { [201, {}, ["ordinary response"]] }
    wrapper = NativeRps::Samples.new(app, {"validation_key" => "test-key"}, nil)
    assert_equal [201, {}, ["ordinary response"]], wrapper.call({})
    assert_equal [201, {}, ["ordinary response"]], wrapper.call({"HTTP_X_LOWRAIL_METRICS" => "wrong-key"})
    status, headers, body = wrapper.call({"HTTP_X_LOWRAIL_METRICS" => "test-key"})
    assert_equal 200, status
    assert_equal "application/json", headers.fetch("content-type")
    snapshot = JSON.parse(body.join)
    assert_equal Process.pid, snapshot.fetch("pid")
    %w[heap_live_slots old_objects malloc_increase_bytes count minor_gc_count major_gc_count total_allocated_objects time].each do |field|
      assert_kind_of Integer, snapshot.fetch("gc").fetch(field)
    end
    assert_operator snapshot.fetch("rss").fetch("VmRSS"), :>, 0
  end
end
