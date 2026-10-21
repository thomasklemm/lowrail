# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../jit_stability"
require_relative "../../gem/lib/lowrail"

class YjitRegressionTest < Minitest::Test
  SCRIPT = File.expand_path("yjit_regression.rb", __dir__)

  def run_arm(arm, mode: "interpreter", prefix: "", worker: false)
    env = %w[RUBYOPT RUBY_YJIT_ENABLE RUBY_ZJIT_ENABLE LOWRAIL_STATS LOWRAIL_OUTCOMES LOWRAIL_UNITS
      LOWRAIL_JIT_DIAGNOSTICS YJIT_DIAG_LIVENESS].to_h { [_1, nil] }
    env["BENCH_JIT"] = mode
    # A missing counter extension is intentional: all exercised paths are
    # native admission probes or refusal BEFORE any measurement machinery.
    env["BENCH_CALLGRIND_EXTENSION"] = "/no-measured-window-permitted"
    code = "#{prefix}\nARGV.replace([#{(worker ? '--worker' : '--liveness').dump}, 'props_variant', #{arm.dump}]); load #{SCRIPT.dump}"
    Open3.capture3(env, RbConfig.ruby, *JitStability.flags(mode),
      "-I#{File.expand_path('../../gem/lib', __dir__)}", "-e", code)
  end

  def test_all_pricing_arms_admit_in_both_modes_and_count_the_expected_path
    %w[interpreter yjit].each do |mode|
      %w[original guarded split checks_original each].each do |arm|
        stdout, stderr, status = run_arm(arm, mode: mode)
        assert status.success?, "#{mode}/#{arm}: #{stderr}"
        result = JSON.parse(stdout)
        assert result.fetch("pass")
        assert result.fetch("guard_valid")
        assert_equal Lowrail::FORMAT, result.fetch("manifest_format")
        assert_equal mode, result.fetch("certification_jit")
        assert_equal mode, result.fetch("actual_jit")
        assert_empty result.fetch("fallbacks")
        if %w[guarded split checks_original].include?(arm)
          assert_operator result.fetch("hits").fetch("0", 0), :>, 0
        else
          assert_empty result.fetch("hits")
        end
      end
    end
  end

  def test_refused_manifest_never_reaches_pricing
    stdout, stderr, status = run_arm("checks_original", prefix: <<~RUBY)
      require #{File.expand_path('../../gem/lib/lowrail', __dir__).dump}
      require 'lowrail/manifest'
      Lowrail::Manifest.singleton_class.prepend(Module.new do
        def new(data, ...)
          super(data.merge('format' => Lowrail::FORMAT + 1), ...)
        end
      end)
    RUBY
    refute status.success?
    assert_empty stdout
    assert_includes stderr, "micro artifact refused: unsupported manifest format"
    refute_includes stderr, "no-measured-window-permitted"
  end

  def test_original_only_emission_cannot_pass_as_an_authorized_candidate
    %w[split checks_original].each do |arm|
      stdout, stderr, status = run_arm(arm, prefix: <<~RUBY)
        require #{File.expand_path('props_variant', __dir__).dump}
        def PropsVariant.source(original, **) = original
      RUBY
      refute status.success?
      result = JSON.parse(stdout)
      assert result.fetch("guard_valid") # A live certificate alone is insufficient.
      assert_empty result.fetch("hits")
      refute result.fetch("pass")
      assert_includes stderr, "untimed liveness failed"
    end
  end

  def test_worker_cannot_bypass_the_counted_preflight
    _, stderr, status = run_arm("split", worker: true)
    refute status.success?
    assert_includes stderr, "YJIT_DIAG_LIVENESS"
    refute_includes stderr, "no-measured-window-permitted"
  end

  def test_driver_refuses_disabled_units_before_starting_a_cohort
    Dir.mktmpdir("props-admission") do |dir|
      out = File.join(dir, "refused")
      # No pricing tools are available to this regression, even if the
      # liveness-before-measurement ordering were accidentally reversed.
      _, stderr, status = Open3.capture3({"RUBYOPT" => nil, "LOWRAIL_UNITS" => "", "BENCH_JIT" => "0",
        "BENCH_JOBS" => "1", "PATH" => "/no-pricing-tools"}, RbConfig.ruby,
        *JitStability.flags("interpreter"), SCRIPT, "props_variant", out)
      refute status.success?
      assert_includes stderr, "untimed liveness refused; no cohort started"
      assert_includes File.read(File.join(out, "liveness-original.log")), "micro unit 0 certificate declined"
      refute File.exist?(File.join(out, "liveness.json"))
      refute File.exist?(File.join(out, "preflight.valgrind.log"))
      assert_empty Dir[File.join(out, "*.callgrind*")]
    end
  end
end
