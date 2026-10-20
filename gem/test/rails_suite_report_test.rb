# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../bench/rails_suite_report"

class RailsSuiteReportTest < Minitest::Test
  include LowrailTest

  def test_duplicate_multiplicities_and_symmetric_flake_controls
    Dir.mktmpdir do |dir|
      pass = { "result" => "pass" }
      fail_a = { "result" => "fail", "failure" => "Assertion: A" }
      fail_b = { "result" => "fail", "failure" => "Assertion: B" }
      off = { "duplicate" => [pass, fail_a], "off_flake" => [pass], "on_flake" => [pass],
        "real" => [pass], "missing" => [pass] }
      on = off.merge("duplicate" => [fail_a, pass], "off_flake" => [fail_a],
        "on_flake" => [fail_a], "real" => [fail_b]).except("missing")
      [off, on, off.merge("off_flake" => [fail_b]), on.merge("on_flake" => [pass])].each_with_index do |data, index|
        File.write("#{dir}/#{index}.shadow.json", JSON.generate({ "outcomes" => data }))
      end
      report = RailsSuiteReport.compare(*4.times.map { "#{dir}/#{_1}" })
      assert_equal [6, 5], report.fetch("observations")
      assert_equal 2, report.fetch("identical")
      assert_equal ["off_flake"], report.fetch("unstable")
      assert_equal ["on_flake"], report.fetch("transient")
      assert_equal %w[missing real], report.fetch("differences").keys.sort
      # Dropping a colliding observation must not be mistaken for equivalence.
      File.write("#{dir}/1.shadow.json", JSON.generate({ "outcomes" => off.merge("duplicate" => [pass]) }))
      assert_equal ["duplicate"], RailsSuiteReport.compare("#{dir}/0", "#{dir}/1").fetch("differences").keys
    end
  end

  def test_separate_build_does_not_change_view_primary_key_results
    checkout = ENV.fetch("LOWRAIL_RAILS_CHECKOUT", File.expand_path("../../.corpus/rails", __dir__))
    skip "prepare the Rails v8.1.4 checkout with script/rails-suite" unless File.file?("#{checkout}/RAILS_VERSION")
    worker = File.expand_path("../../bench/ar_rails_suite.rb", __dir__)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/.lowrail")
      env = { "LOWRAIL_ROOT" => dir, "LOWRAIL_SQL_TRACE" => "0", "ARCONN" => "sqlite3_mem" }
      build = env.merge("LOWRAIL" => "0", "LOWRAIL_OUTCOMES" => "#{dir}/build", "RAILS_SUITE_LAYER" => "build", "RAILS_SUITE_BUILD" => dir)
      out, err, status = ruby(worker, "test/cases/view_test.rb", "--seed", "41231", env: build, chdir: "#{checkout}/activerecord")
      assert status.success?, "#{out}\n#{err}"
      assert File.file?("#{dir}/.lowrail/manifest.json"), "build must finish without running Minitest"
      %w[0 1].each do |mode|
        run_env = env.merge("LOWRAIL" => mode, "LOWRAIL_OUTCOMES" => "#{dir}/#{mode}", "RAILS_SUITE_LAYER" => mode == "0" ? "L1" : "L3")
        out, err, status = ruby(worker, "test/cases/view_test.rb", "--seed", "41231", env: run_env, chdir: "#{checkout}/activerecord")
        assert status.success?, "#{out}\n#{err}"
      end
      report = RailsSuiteReport.compare("#{dir}/0", "#{dir}/1")
      assert_equal [17, 17], report.fetch("observations")
      assert_equal({}, report.fetch("differences"))
      assert_empty JSON.parse(File.read("#{dir}/1")).fetch("unit_hits"), "L3 test process must not activate sealed-only AR candidates"
    end
  end

  def test_profiling_preserves_backtrace_cleaner_results
    checkout = ENV.fetch("LOWRAIL_RAILS_CHECKOUT", File.expand_path("../../.corpus/rails", __dir__))
    gemfile = File.expand_path("../../.lowrail/rails-suite/Gemfile", __dir__)
    skip "prepare the Rails v8.1.4 bundle with script/rails-suite" unless
      File.file?("#{checkout}/RAILS_VERSION") && File.file?(gemfile)
    worker = File.expand_path("../../bench/ar_rails_suite.rb", __dir__)
    Dir.mktmpdir do |dir|
      profile = "#{dir}/off.stackprof"
      env = { "BUNDLE_GEMFILE" => gemfile, "LOWRAIL" => "0", "LOWRAIL_ROOT" => dir, "LOWRAIL_OUTCOMES" => "#{dir}/off",
        "LOWRAIL_SQL_TRACE" => "0", "RAILS_SUITE_LAYER" => "L1", "RAILS_SUITE_PROFILE" => profile }
      out, err, status = ruby(worker, "test/backtrace_cleaner_test.rb", "--seed", "41231",
        env: env, chdir: "#{checkout}/activesupport")
      assert status.success?, "#{out}\n#{err}"
      assert_operator Marshal.load(File.binread(profile)).fetch(:samples), :>, 0
    end
  end
end
