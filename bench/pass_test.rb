# frozen_string_literal: true

require "minitest/autorun"
require_relative "pass"

class PassBenchTest < Minitest::Test
  def manifest
    { "format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
      "rails_env" => "production", "compile_option" => {}, "units" => [], "files" => {}, "templates" => {} }
  end

  def run_rejection(data, **options)
    Dir.mktmpdir("lowrail-pass-test") do |app|
      FileUtils.mkdir_p(File.join(app, ".lowrail"))
      File.write(File.join(app, ".lowrail/manifest.json"), JSON.generate(data))
      out = File.join(app, "result")
      capture_io { refute PassBench.run(app, pass: "default", out: out, **options) }
      result = JSON.parse(File.read(File.join(out, "result.json")))
      assert_equal "rejected", result.fetch("status")
      refute result.fetch("measurement_complete")
      assert_includes File.read(File.join(out, "table.md")), "rejected"
      yield result
    end
  end

  def test_stale_manifest_is_a_rejected_measurement_not_a_silent_noop
    run_rejection(manifest.merge("ruby_description" => "obsolete Ruby")) do |result|
      assert_includes result.fetch("error"), "incompatible Ruby/format"
    end
    run_rejection(manifest.merge("units" => [{ "id" => 0, "pass" => "route/path", "facts" => [] }],
      "templates" => { "/missing/template.erb" => { "source_sha256" => "stale" } })) do |result|
      assert_includes result.fetch("error"), "stale build"
    end
  end

  def test_zero_units_cannot_masquerade_as_active_pass_measurement
    run_rejection(manifest) { assert_includes _1.fetch("error"), "no units" }
  end

  def test_one_boot_cannot_masquerade_as_independent_native_cohorts
    saved = ENV["BENCH_COHORTS"]
    ENV["BENCH_COHORTS"] = "1"
    run_rejection(manifest, counter: "native") { assert_includes _1.fetch("error"), "five independent cohorts" }
  ensure
    ENV["BENCH_COHORTS"] = saved
  end

  def test_archived_runtime_cannot_compare_different_pass_selections
    saved = ENV["BENCH_BASELINE_LIB"]
    ENV["BENCH_BASELINE_LIB"] = "/unused/archived/lib"
    run_rejection(manifest, pass: "route/path") { assert_includes _1.fetch("error"), "requires --pass default" }
  ensure
    ENV["BENCH_BASELINE_LIB"] = saved
  end

  def test_stack_requires_an_actual_default_reference_not_an_optional_build
    options = { pass: nil, passes: "route/path,active_record/instantiate", default_passes: "route/path" }
    run_rejection(manifest, **options) { assert_includes _1.fetch("error"), "needs --default-build" }
    data = manifest.merge("units" => [{ "id" => 0, "pass" => "route/path", "facts" => [] }])
    Dir.mktmpdir("lowrail-default-reference-test") do |dir|
      File.write(File.join(dir, "manifest.json"), JSON.generate(manifest.merge("units" => [{ "id" => 1, "pass" => "active_record/instantiate", "facts" => [] }])))
      run_rejection(data, **options, default_build: dir) { assert_includes _1.fetch("error"), "reference contains opt-in" }
      File.write(File.join(dir, "manifest.json"), JSON.generate(manifest.merge("units" => [{ "id" => 0, "pass" => "route/path", "file" => "/another/app.rb", "facts" => [] }])))
      run_rejection(data, **options, default_build: dir) { assert_includes _1.fetch("error"), "another app" }
    end
  end

  def test_non_ar_certificates_are_checked_against_the_loaded_library_too
    Dir.mktmpdir("lowrail-pass-certificate") do |dir|
      lib = File.join(dir, "lib")
      FileUtils.mkdir_p(File.join(lib, "lowrail"))
      original = File.expand_path("../gem/lib/lowrail/memo.rb", __dir__)
      target = File.join(lib, "lowrail/memo.rb")
      FileUtils.cp(original, target)
      data = manifest.merge("units" => [{ "id" => 0, "pass" => "memo/sha256", "facts" => [],
        "memo" => { "sources" => { original => { "sha256" => Digest::SHA256.file(original).hexdigest,
          "size" => File.size(original), "mtime" => File.mtime(original).to_r.to_s } } } }])
      File.write(File.join(dir, "manifest.json"), JSON.generate(data))
      assert_equal data, PassBench.preflight(dir, lib)
      File.write(target, "changed")
      error = assert_raises(RuntimeError) { PassBench.preflight(dir, lib) }
      assert_includes error.message, "stale build"
      binary = File.join(dir, "endpoint.bin")
      File.binwrite(binary, RubyVM::InstructionSequence.compile("Module.new").to_binary)
      data = manifest.merge("units" => [{ "id" => 0, "pass" => "endpoint/action", "facts" => [],
        "endpoint" => { "templates" => {}, "iseq" => "endpoint.bin", "iseq_sha256" => Digest::SHA256.file(binary).hexdigest } }])
      File.write(File.join(dir, "manifest.json"), JSON.generate(data))
      assert_equal data, PassBench.preflight(dir, lib)
      File.binwrite(binary, "corrupt")
      error = assert_raises(RuntimeError) { PassBench.preflight(dir, lib) }
      assert_includes error.message, "stale build"
    end
  end

  def test_stack_budgets_preserve_models_signed_savings_and_shared_control_covariance
    units = [
      { "id" => 11, "pass" => "active_record/instantiate", "ar_instantiate" => { "model" => "Article" } },
      { "id" => 12, "pass" => "active_record/instantiate", "ar_instantiate" => { "model" => "Comment" } },
      { "id" => 3, "pass" => "view/link_to" }
    ]
    result = { manifest_sha256: "build", runtime_fingerprint_sha256: "runtime", request_context_sha256: "request", route: "GET:/articles", counter: "callgrind",
      coverage: { "yjit" => false, "units" => [{ "id" => 11, "hits_per_request" => 12 },
        { "id" => 12, "hits_per_request" => 1 }, { "id" => 3, "hits_per_request" => 9 }] } }
    entries = units.each_with_index.map do |unit, i|
      costs = [[1, 2, 3, 4, 5, 6], [19, 16, 13, 10, 7, 4], [-2, -2, -2, -2, -2, -2]].fetch(i)
      unit.slice("id", "pass").merge("model" => unit.dig("ar_instantiate", "model"), "guard_included" => true,
        "source" => "test fixture, not corpus evidence", "hits_per_iteration" => i + 1,
        "samples" => costs.map { { "off_a" => 1000, "off_b" => 1000, "on" => 1000 - _1 * (i + 1) } })
    end
    entries.first["hits_per_iteration"] = 4 # fractional instructions/hit must not truncate
    entries.last["completed_hits_per_request_samples"] = [5] * 6
    budget = { "schema_version" => 1, "metric" => "instructions_total", "yjit" => false,
      "manifest_sha256" => "build", "runtime_fingerprint_sha256" => "runtime", "request_context_sha256" => "request", "route" => "GET:/articles", "units" => entries }
    raw = { "samples" => Array.new(6) do
      { "off_a" => { "instructions_total" => 1000, "instructions_no_gc" => 900 },
        "default" => { "instructions_total" => 960, "instructions_no_gc" => 880 },
        "stacked" => { "instructions_total" => 930, "instructions_no_gc" => 875 } }
    end }
    Dir.mktmpdir("lowrail-stack-budget-test") do |dir|
      file = File.join(dir, "budget.json")
      File.write(file, JSON.generate(budget))
      accepted = StackBudget.validate!(JSON.parse(File.read(file)), result, units)
      report = StackBudget.report(raw, result, accepted, ["view/link_to"], seed: 1)
      no_setup = report.fetch(:comparisons).fetch("no_setup").fetch("instructions_total")
      default = report.fetch(:comparisons).fetch("default").fetch("instructions_total")
      assert_equal({ median: 12.0, ci95: [12.0, 12.0] }, no_setup.fetch(:sum_individual_expected_saved_per_request))
      assert_equal({ median: 22.0, ci95: [22.0, 22.0] }, default.fetch(:sum_individual_expected_saved_per_request))
      assert_equal 58.0, no_setup.fetch(:measured_minus_expected).fetch(:median)
      assert_equal 8.0, default.fetch(:measured_minus_expected).fetch(:median)
      assert_equal [11, 12, 3], report.fetch(:units).map { _1.fetch(:id) }
      assert_empty report.fetch(:unmodeled_unit_ids)
      assert_in_delta(-7.0, no_setup.fetch(:delta_pct).fetch(:median), 1e-9)
      defaults_only = accepted.merge("units" => [entries.last])
      partial = StackBudget.report(raw, result, defaults_only, ["view/link_to"], seed: 1)
      refute partial[:comparisons]["default"]["instructions_total"].key?(:sum_individual_expected_saved_per_request), "missing opt-in prices are not zero"
      source_result = result.merge(coverage: { "units" => [result.fetch(:coverage).fetch("units").last] })
      no_opt_ins = StackBudget.report(raw, source_result, defaults_only, ["view/link_to"], seed: 1)
      assert_equal({ median: 0, ci95: [0, 0] }, no_opt_ins[:comparisons]["default"]["instructions_total"][:sum_individual_expected_saved_per_request])
      # These reject tempting but invalid substitutions before any requests run.
      [->(b) { b["yjit"] = true }, ->(b) { b["metric"] = "wall_us" },
        ->(b) { b["request_context_sha256"] = "different user/cache" },
        ->(b) { b["manifest_sha256"] = "old" }, ->(b) { b["units"][0]["model"] = "Comment" },
        ->(b) { b["units"][0]["samples"].each { _1["off_b"] = 1100 } },
        ->(b) { b["units"][2].delete("completed_hits_per_request_samples") }].each do |break_control|
        broken = Marshal.load(Marshal.dump(budget))
        break_control.call(broken)
        File.write(file, JSON.generate(broken))
        assert_raises(RuntimeError) { StackBudget.validate!(JSON.parse(File.read(file)), result, units) }
      end
    end
  end

  def test_native_stack_uncertainty_resamples_boots_not_repeated_blocks
    raw = { "cohorts" => [50, 60, 70, 80, 90].map do |saving|
      { "samples" => Array.new(40) do
        { "off_a" => { "cpu_us" => 1000, "wall_us" => 2000 },
          "default" => { "cpu_us" => 980, "wall_us" => 1900 },
          "stacked" => { "cpu_us" => 1000 - saving, "wall_us" => 2000 - 2 * saving } }
      end }
    end }
    coverage = { "units" => [{ "id" => 71, "hits_per_request" => 0, "fallbacks_per_request" => 2 }] }
    report = StackBudget.report(raw, { counter: "native", coverage: coverage }, nil, [], seed: 1)
    assert_equal({ median: 70, ci95: [50, 90] }, report[:comparisons]["no_setup"]["cpu_us"][:measured_saved_per_request])
    assert_equal 40, report[:comparisons]["default"]["wall_us"][:measured_saved_per_request][:median]
    assert_equal "not_supplied", report[:budget_status]
    assert_equal [71], report[:unmodeled_fallback_unit_ids], "zero fast-path hits do not make fallback guards free"
    refute report[:comparisons]["default"]["wall_us"].key?(:sum_individual_expected_saved_per_request)
  end

  def test_guarded_fallback_invocations_are_priced_without_inventing_fast_path_hits
    units = [{ "id" => 7, "pass" => "route/path" }]
    result = { manifest_sha256: "build", runtime_fingerprint_sha256: "runtime", request_context_sha256: "request",
      route: "GET:/room", counter: "callgrind", passes: ["route/path"],
      coverage: { "yjit" => false, "units" => [{ "id" => 7, "hits_per_request" => 5, "fallbacks_per_request" => 0 }] } }
    entry = { "id" => 7, "pass" => "route/path", "count_kind" => "invocation", "guard_included" => true,
      "source" => "synthetic arithmetic fixture, not corpus evidence", "invocations_per_iteration" => 7,
      "invocations_per_request_samples" => [5] * 6, "completed_hits_per_request_samples" => [0] * 6,
      "samples" => Array.new(6) { { "off_a" => 1000, "off_b" => 1000, "on" => 1007 } } }
    budget = result.slice(:manifest_sha256, :runtime_fingerprint_sha256, :request_context_sha256, :route).transform_keys(&:to_s)
      .merge("schema_version" => 1, "metric" => "instructions_total", "yjit" => false, "units" => [entry])
    StackBudget.validate!(budget, result, units)
    raw = { "samples" => Array.new(6) do
      %w[off_a default stacked].to_h { [_1, { "instructions_total" => _1 == "off_a" ? 1000 : 1005, "instructions_no_gc" => 900 }] }
    end }
    report = StackBudget.report(raw, result, budget, ["route/path"], seed: 1)
    modeled = report.fetch(:units).first
    assert_equal(-1.0, modeled.fetch(:saved_per_invocation).fetch(:median))
    refute modeled.key?(:saved_per_hit)
    assert_equal [0] * 6, modeled.fetch(:completed_hits_per_request)
    assert_equal(-5.0, report[:comparisons]["no_setup"]["instructions_total"][:sum_individual_expected_saved_per_request][:median])
    assert_equal 0, report[:comparisons]["no_setup"]["instructions_total"][:measured_minus_expected][:median]
    entry["completed_hits_per_request_samples"] = [6] * 6
    assert_raises(RuntimeError) { StackBudget.validate!(budget, result, units) }
  end

  def test_source_replays_preserve_unicode_literal_policy_and_separate_nested_passes
    script = <<~'RUBY'
      require "operation_capture"
      module Lowrail
        K = [nil, nil]
        def self.ok?(*args) = true
      end
      module OperationCapture
        def self.record(key, context) = yield
      end
      units = [{"id" => 0, "pass" => "view/link_to"}, {"id" => 1, "pass" => "route/path"}]
      code = %q[# frozen_string_literal: true
      label = "café"; ((::Lowrail.ok?(0, self.class)) ? "link:#{((::Lowrail.ok?(1, self.class)) ? "route" : "original")}" : "fallback")
      # trailing comment
      ]
      cached = code.gsub(/::Lowrail\.ok\?\((\d+), self\.class\)/) do
        "(self.class.equal?(::Lowrail::K[#{$1}]) || #{$&})"
      end
      results = [[code, [nil, nil]], [cached, [nil, nil]], [cached, [Object, Object]]].map do |input, classes|
        Lowrail::K.replace(classes)
        source = OperationCapture::Source.new(input, "example.rb", units)
        parent, child = source.specs
        values = [eval(source.instrument), eval(source.expression(parent)), eval(source.original(parent)), eval(source.expression(child))]
        {values: values, frozen: eval(source.literal_policy + source.original(parent)).frozen?}
      end
      puts JSON.generate(results)
    RUBY
    output, error, status = Open3.capture3(RbConfig.ruby, "-I#{__dir__}", "-e", script)
    assert status.success?, error
    expected = { "values" => ["link:route", "link:original", "fallback", "route"], "frozen" => true }
    assert_equal [expected, expected, expected], JSON.parse(output)
  end

  def test_runtime_builder_uses_requested_jit_state_without_changing_the_default
    Dir.mktmpdir("lowrail-build-jit") do |app|
      FileUtils.mkdir_p(File.join(app, "config"))
      File.write(File.join(app, "config/application.rb"), <<~RUBY)
        module Rails
          def self.application = (@app ||= self)
          def self.config = (@config ||= Struct.new(:yjit).new(true))
          def self.eager_load!; end
        end
      RUBY
      File.write(File.join(app, "config/environment.rb"), <<~RUBY)
        require_relative "application"
        RubyVM::YJIT.enable if Rails.application.config.yjit
        File.write("observed.json", JSON.generate(yjit: !!RubyVM::YJIT.enabled?))
      RUBY
      [nil, "0"].each do |mode|
        output, error, status = Open3.capture3({ "RUBYOPT" => nil, "LOWRAIL_BUILD_JIT" => mode },
          RbConfig.ruby, "--disable-yjit", File.expand_path("../gem/exe/lowrail-runtime-build", __dir__),
          chdir: app, stdin_data: JSON.generate(builders: [], denied: []))
        assert status.success?, error
        assert_equal [], JSON.parse(output)
        assert_equal(mode.nil?, JSON.parse(File.read(File.join(app, "observed.json"))).fetch("yjit"))
      end
      File.write(File.join(app, "config/environment.rb"), "require_relative 'application'; RubyVM::YJIT.enable\n")
      _, error, status = Open3.capture3({ "RUBYOPT" => nil, "LOWRAIL_BUILD_JIT" => "0" },
        RbConfig.ruby, "--disable-yjit", File.expand_path("../gem/exe/lowrail-runtime-build", __dir__),
        chdir: app, stdin_data: JSON.generate(builders: [], denied: []))
      refute status.success?
      assert_includes error, "runtime build unexpectedly enabled YJIT"
    end
  end

  def test_replay_keeps_live_request_fallbacks_lexical_constants_and_snapshotted_locals
    script = <<~'RUBY'
      require "operation_capture"
      require "tmpdir"
      module ActiveSupport
        class CurrentAttributes
          def self.descendants = [RequestCurrent]
        end
      end
      class RequestCurrent
        attr_accessor :attributes
        def self.instance = (@instance ||= new)
        def self.attributes = instance.attributes
      end
      module Lowrail
        class << self
          attr_accessor :manifest
          def ok?(*args) = true
        end
        module Loader; end
        module Templates
          def self.entries = (@entries ||= {})
        end
        module Routes
          def self.finish(value) = value
        end
      end
      class View
        TOKEN = "receiver"
        def optimize_routes_generation? = RequestCurrent.attributes.empty?
        def original = "original"
      end
      module Lexical
        TOKEN = "lexical"
        def self.context = View.new.instance_eval { suffix = "before"; binding }
      end
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "units.json"), JSON.generate(files: []))
        code = '((::Lowrail.ok?(0, self.class)) ? (optimize_routes_generation? ? ::Lowrail::Routes.finish(TOKEN + suffix) : original) : original)'
        Lowrail.manifest = Struct.new(:templates, :files, :units, :dir).new(
          {"context.rb" => {"code" => code}, "other.rb" => {"code" => code.sub("ok?(0,", "ok?(1,")}},
          {}, [{"id" => 0, "pass" => "route/path"}, {"id" => 1, "pass" => "route/path"}], dir)
        OperationCapture.install
        RequestCurrent.instance.attributes = {host: "localhost"}
        context = Lexical.context
        OperationCapture.capture do
          context.eval(Lowrail::Templates.entries.fetch("context.rb").fetch("code"))
          RequestCurrent.instance.attributes = {}
          context.eval(Lowrail::Templates.entries.fetch("other.rb").fetch("code"))
        end
        context.local_variable_set(:suffix, "after")
        RequestCurrent.instance.attributes = {} # Rails executor cleanup
        OperationCapture.restore_context(0)
        pair = OperationCapture.records.fetch(0).first
        fallback = pair.fetch(:counted).call
        counts = [OperationCapture.request_completions[0], OperationCapture.completions[0]]
        OperationCapture.restore_context(1)
        other = OperationCapture.records.fetch(1).first.fetch(:counted).call
        RequestCurrent.instance.attributes = {}
        puts JSON.generate(fallback: fallback, completions: counts, other: other,
          other_completions: [OperationCapture.request_completions[1], OperationCapture.completions[1]],
          lexical_snapshot: pair.fetch(:expression).call)
      end
    RUBY
    output, error, status = Open3.capture3(RbConfig.ruby, "-I#{__dir__}", "-e", script)
    assert status.success?, error
    assert_equal({ "fallback" => "original", "completions" => [0, 0], "other" => "lexicalbefore",
      "other_completions" => [1, 1], "lexical_snapshot" => "lexicalbefore" }, JSON.parse(output))
  end

  def test_jit_state_is_observed_after_application_boot_not_inferred_from_flags
    Dir.mktmpdir("lowrail-pass-jit") do |app|
      FileUtils.mkdir_p(File.join(app, "config"))
      # A production app can explicitly enable YJIT during initialization.
      File.write(File.join(app, "config/application.rb"), <<~RUBY)
        raise "JSON activated before the app can lock its gems" if defined?(JSON)
        module Rails
          Config = Struct.new(:yjit)
          class Application
            def config = (@config ||= Config.new)
            def eager_load!; end
          end
          def self.application = (@app ||= Application.new)
          def self.logger = (@logger ||= Struct.new(:level).new)
        end
      RUBY
      File.write(File.join(app, "config/environment.rb"), "require_relative 'application'; RubyVM::YJIT.enable\n")
      env = { "RUBYOPT" => nil, "BENCH_JIT" => "0", "BENCH_UNITS" => "0" }
      error = assert_raises(RuntimeError) { PassBench.probe(app, app, env, "GET:/", "jit") }
      assert_includes error.message, "activation/JIT probe failed"
      assert_includes File.read(File.join(app, "jit.log")), "unexpected JIT mode"
    end
  end
end
