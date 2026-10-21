# frozen_string_literal: true

require_relative "test_helper"

# LOWRAIL_OUTCOMES: per-test outcomes plus unit hits, loaded only through
# RUBYOPT (no Gemfile change, no require in the suite).
class MinitestPluginTest < Minitest::Test
  include LowrailTest

  SUITE = <<~'RUBY'
    require "minitest/autorun"
    require File.join(Dir.pwd, "app")

    class SampleTest < Minitest::Test
      def test_pass
        5.times { assert_equal 2, Calc.new.compute(1)[1] }
      end

      def test_fail = assert_equal(1, 2)

      def test_error = raise(ArgumentError, "boom #{Object.new.inspect}\nsecond line")

      def test_skip = skip("later")
    end
  RUBY

  def run_suite(dir, env = {})
    File.write(File.join(dir, "sample_test.rb"), SUITE)
    out_path = File.join(dir, "outcomes.json")
    _out, err, status = ruby("sample_test.rb", chdir: dir, env: { "LOWRAIL_OUTCOMES" => out_path }.merge(env))
    refute status.success?, "suite has a failing test" # sanity: the reporter must not change the exit status
    assert File.file?(out_path), "no outcomes written:\n#{err}"
    [JSON.parse(File.read(out_path)), Dir[File.join(dir, "outcomes.json.*")]]
  end

  def test_outcomes_and_hits
    realpath_tmpdir do |dir|
      build_app(dir)
      data, per_process = run_suite(dir)
      tests = data.fetch("tests")
      assert_equal({ "result" => "pass" }, tests["SampleTest#test_pass"])
      assert_equal "fail", tests["SampleTest#test_fail"]["result"]
      assert_equal "Minitest::Assertion: Expected: 1", tests["SampleTest#test_fail"]["failure"]
      assert_equal "error", tests["SampleTest#test_error"]["result"]
      assert_equal "ArgumentError: boom #<Object:0x?>", tests["SampleTest#test_error"]["failure"]
      assert_equal "skip", tests["SampleTest#test_skip"]["result"]
      assert_equal "Minitest::Skip: later", tests["SampleTest#test_skip"]["failure"]
      assert_equal({ "0" => 5 }, data["unit_hits"])
      assert_equal 1, per_process.size
      refute data.key?("jit_diagnostics"), "diagnostics are opt-in"
      # Diagnostics must exercise a mode-matched artifact, not an early refusal.
      input = File.join(dir, "units.json")
      File.write(input, JSON.generate(JSON.parse(File.read(input)).merge("certification_jit" => "yjit")))
      _, err, status = ruby(COMPILE, input, setup: false)
      assert status.success?, err
      diagnosed, = run_suite(dir, "LOWRAIL_JIT_DIAGNOSTICS" => "1", "RUBYOPT" => "#{SETUP_OPT} --yjit")
      assert_equal data["tests"], diagnosed["tests"]
      assert_equal data["unit_hits"], diagnosed["unit_hits"]
      snapshot = diagnosed.fetch("jit_diagnostics").fetch(0)
      assert_includes snapshot["ruby"], "ruby #{RUBY_VERSION}"
      assert_equal true, snapshot.dig("jits", "yjit", "enabled")
      assert_equal false, snapshot.dig("jits", "zjit", "enabled")
      assert_nil snapshot["per_iseq_counters"]
      assert_equal [0, 1], snapshot.fetch("delivered_method_iseqs").flat_map { _1.fetch("candidate_unit_ids") }.sort
    end
  end

  def test_outcomes_without_lowering
    realpath_tmpdir do |dir|
      build_app(dir)
      data, = run_suite(dir, "LOWRAIL" => "0")
      assert_equal 4, data["tests"].size
      assert_equal({}, data["unit_hits"])
    end
  end

  def test_opt_in_load_census_observes_but_never_forces_autoloads
    skip "Active Support and Zeitwerk are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "models"))
      late = File.join(dir, "models/census_late.rb")
      File.write(late, "class CensusLate; end\nActiveSupport.run_load_hooks(:census_probe)\n")
      File.write(File.join(dir, "models/untouched.rb"), "raise 'observer forced an autoload'\n")
      File.write(File.join(dir, "suite.rb"), <<~'RUBY')
        require "minitest/autorun"
        require "active_support/lazy_load_hooks"
        require "zeitwerk"
        loader = Zeitwerk::Loader.new
        loader.push_dir(File.join(Dir.pwd, "models"))
        loader.setup
        ActiveSupport.on_load(:census_probe) { $hook_calls = ($hook_calls || 0) + 1 }
        class CensusTest < Minitest::Test
          def test_late_load
            assert_equal "CensusLate", CensusLate.name
            assert_equal 1, $hook_calls
          end
        end
      RUBY
      %w[0 1].each do |mode|
        path = File.join(dir, "outcomes-#{mode}.json")
        _out, err, status = ruby("suite.rb", chdir: dir, env: {
          "LOWRAIL" => mode, "LOWRAIL_OUTCOMES" => path, "LOWRAIL_VERIFY_LOADS" => "1" })
        assert status.success?, err
        census = JSON.parse(File.read(path)).fetch("verify_loads")
        first, last = census.fetch("stages").values_at("first_test", "after_suite")
        refute_includes first.fetch("constants"), "CensusLate"
        assert_includes last.fetch("constants"), "CensusLate"
        refute_includes first.fetch("zeitwerk_paths"), late
        assert_includes last.fetch("zeitwerk_paths"), late
        assert last.fetch("on_load_hooks").any? { _1.start_with?("census_probe\t") }
        refute_includes last.fetch("constants"), "Untouched"
        assert_operator census.fetch("snapshot_seconds"), :>, 0
      end
    end
  end

  RAILS_SUITE = <<~'RUBY'
    require "active_support"
    require "active_support/test_case"
    require "active_support/testing/autorun"
    require File.join(Dir.pwd, "app")
    Calc.new.compute(1) # a hit in the parent before the workers fork

    class ParallelTest < ActiveSupport::TestCase
      parallelize(workers: 2, with: :processes, threshold: 0)
      8.times do |i|
        test("hit #{i}") { assert_equal 2, Calc.new.compute(1)[1] }
      end
      test("fails") { assert_equal 1, Calc.new.compute(1)[1] }
      test("errors") { raise KeyError, "nope" }
    end
  RUBY

  # Rails runs tests in forked workers and sends results to the parent over
  # DRb: outcomes are recorded in the parent, hits in the children; the
  # parent merges the children's files after waiting for them.
  def test_rails_parallel_workers
    begin
      require "active_support/testing/parallelization"
    rescue LoadError
      skip "activesupport not installed"
    end
    realpath_tmpdir do |dir|
      build_app(dir)
      File.write(File.join(dir, "parallel_test.rb"), RAILS_SUITE)
      out_path = File.join(dir, "outcomes.json")
      _out, err, _status = ruby("parallel_test.rb", chdir: dir, env: { "LOWRAIL_OUTCOMES" => out_path })
      assert File.file?(out_path), err
      data = JSON.parse(File.read(out_path))
      assert_equal 10, data["tests"].size, data["tests"].keys.inspect
      assert_equal "pass", data["tests"]["ParallelTest#test_hit_3"]["result"]
      assert_equal "fail", data["tests"]["ParallelTest#test_fails"]["result"]
      assert_equal "error", data["tests"]["ParallelTest#test_errors"]["result"]
      assert_equal "KeyError: nope", data["tests"]["ParallelTest#test_errors"]["failure"]
      assert_equal({ "0" => 10 }, data["unit_hits"], "parent hit counted once, not once per worker")
      assert_operator data["processes"].size, :>=, 2, "worker files merged"
    end
  end
end
