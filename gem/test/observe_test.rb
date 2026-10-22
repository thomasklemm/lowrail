# frozen_string_literal: true

# The observed-run recorder (lowrail/observe via RUBYOPT) on the minimal
# Rails app of test_helper.rb, with a two-test Minitest suite.
#   ruby -Igem/lib -Igem/test gem/test/observe_test.rb

require "test_helper"

class ObserveTest < Minitest::Test
  include LowrailTest

  SUITE = {
    "test/test_helper.rb" => <<~'RUBY',
      ENV["RAILS_ENV"] ||= "test"
      # Unlike a bundled app, this fixture has no dependency resolution step.
      # Select Minitest's compatible Prism before Rails loads its ERB parser.
      require "minitest/autorun"
      require_relative "../config/environment"
      require "rails/test_help"
    RUBY
    "test/models/widget_test.rb" => <<~'RUBY',
      require_relative "../test_helper"

      class WidgetTest < ActiveSupport::TestCase
        def test_label
          w = Widget.new(name: "a", status: :live)
          20.times { assert_equal "a (live)", w.label }
          w.greet("x", loud: true)
          w.greet(:y)
          w.instance_variable_set(:@sample, "first")
          w.greet(:z)
          w.instance_variable_set(:@sample, 9)
          w.greet(:last)
        end

        def test_relation_delegation
          Widget.create!(name: "b", password: "secret")
          assert_equal "b", Widget.named.cheapest.name
        end

        def test_exception_samples
          probe = ReturnProbe.new
          6.times { assert_raises(RangeError) { probe.failing(:bad) } }
          assert_raises(ArgumentError) { probe.indirect { Integer("bad") } }
          assert_raises(RangeError) { probe.recursive(2, true) }
          assert_equal "done", probe.recursive(0, false)
          assert_instance_of ReturnProbe::Value, probe.rescued
          assert_nil probe.rescued_nil
          assert_equal :saved, probe.ensure_return
          assert_raises(RangeError) { probe.ensured }
          begin
            raise "ambient, outside the sampled frames"
          rescue
            assert_nil probe.normal_nil
            assert_equal "value", probe.normal_value
          end
          paused = Fiber.new { probe.interleaved(false) }
          paused.resume
          assert_raises(RangeError) { Fiber.new { probe.interleaved(true) }.resume }
          assert_equal :safe, paused.resume
          entered, leave = Queue.new, Queue.new
          thread = Thread.new { probe.concurrent(entered, leave) }
          entered.pop
          assert_raises(ArgumentError) { probe.indirect { Integer("bad") } }
          leave << true
          assert_equal :safe, thread.value
        end
      end
    RUBY
    "app/models/return_probe.rb" => <<~'RUBY',
      class ReturnProbe
        class Value
          def nil? = raise "the recorder must not call the returned object's methods"
        end
        def failing(value)
          @partial = value
          raise RangeError, "no normal return"
        end
        def indirect
          yield
        end
        def recursive(depth, fail)
          recursive(depth - 1, fail) if depth > 0
          raise RangeError if fail
          "done"
        end
        def rescued
          raise RangeError
        rescue
          Value.new
        end
        def rescued_nil
          raise RangeError
        rescue
          nil
        end
        def ensured
          raise RangeError
        ensure
          @partial = :ensured
        end
        def ensure_return
          raise RangeError
        ensure
          return :saved
        end
        def normal_nil = nil
        def normal_value = "value"
        def interleaved(fail)
          Fiber.yield unless fail
          raise RangeError if fail
          :safe
        end
        def concurrent(entered, leave)
          entered << true
          leave.pop
          :safe
        end
      end
    RUBY
  }.freeze

  def self.observed_run(samples: 4, types_only: false)
    @runs ||= {}
    @runs[[samples, types_only]] ||= begin
      dir = File.realpath(Dir.mktmpdir("lowrail-obs"))
      LowrailTest.write_rails_app(dir, SUITE)
      obs = File.join(dir, ".lowrail", "observe")
      env = CLEAN_ENV.merge("RUBYOPT" => "-I#{GEM_LIB} -rlowrail/observe", "LOWRAIL" => "0",
                            "LOWRAIL_OBSERVE" => obs, "LOWRAIL_OBSERVE_SAMPLES" => samples.to_s,
                            "LOWRAIL_OBSERVE_TYPES_ONLY" => types_only ? "1" : "0",
                            "LOWRAIL_OBSERVE_METHODS" => "ActiveRecord::Base#save!,ActiveRecord::Base#save!,Nope#missing")
      out, err, status = Open3.capture3(env, RUBY, "-Itest", "test/models/widget_test.rb", chdir: dir)
      files = Dir[File.join(obs, "observed-*.json")]
      data = files.size == 1 ? JSON.parse(File.read(files.first)) : nil
      [dir, data, out + err, status]
    end
  end

  def setup
    missing_prerequisite "Rails, sqlite3 or bcrypt not installed" unless LowrailTest.rails_installed?
    @dir, @o, @log, @status = self.class.observed_run
    assert @status.success?, @log
    refute_nil @o, "one observed-<pid>.json expected:\n#{@log}"
  end

  def defined(mod, name, singleton: false)
    @o["defined_after_boot"].find { |m| m["module"] == mod && m["name"] == name && m["singleton"] == singleton }
  end

  def types(mod, name, singleton: false)
    @o["types"].find { |t| t["module"] == mod && t["name"] == name && t["singleton"] == singleton }
  end

  def test_suite_passes_with_recorder
    assert_match(/3 runs, \d+ assertions, 0 failures, 0 errors/, @log)
    assert_match(/cannot hook Nope#missing/, @log)
  end

  def test_definitions_after_boot
    # Without materialize, attribute methods appear during the run.
    m = defined("Widget::GeneratedAttributeMethods", "name")
    refute_nil m
    if (reason = @o["generated_stats"]["linking_decline"])
      assert_match(/\Aiseq_identity_unavailable:/, reason)
      refute m.key?("script")
      assert(@o["generated_scripts"].any? { |s| s["phase"] == "test" })
    else
      assert m["script"], "linked to its generated script"
      assert(@o["generated_scripts"].any? { |s| s["sha256"] == m["script"] && s["phase"] == "test" })
      assert File.exist?(File.join(@dir, ".lowrail", "generated", "#{m["script"]}.rb"))
    end
    # Relation delegation generated on first call through a relation.
    assert defined("Widget::GeneratedRelationMethods", "cheapest")
    # Test code is defined after boot too.
    assert_equal "test/models/widget_test.rb:4", defined("WidgetTest", "test_label")["source_location"]
    assert_operator @o["modules_after_boot"], :>, 0
    %w[boot_seconds snapshot_seconds exit_seconds].each { |k| assert_kind_of Numeric, @o["timings"][k] }
  end

  def test_type_samples_are_bounded
    label = types("Widget", "label")
    assert_equal({"String" => 4}, label["returns"])
    assert_equal({"Widget" => 4}, label["self"])
    assert_equal 4, label["calls"]
    assert label["saturated"]
    cheapest = types("#<Class:Widget>", "cheapest", singleton: true)
    assert_equal({"Widget" => 1}, cheapest["returns"])
    # Framework method from LOWRAIL_OBSERVE_METHODS.
    save = types("ActiveRecord::Base", "save!")
    refute_nil save, @o["types"].map { |t| t.values_at("module", "name") }.inspect
    assert_equal 1, @o["types"].count { |t| t["module"] == "ActiveRecord::Base" && t["name"] == "save!" }, "repeated targets must not duplicate profiles"
    assert_equal({"TrueClass" => 1}, save["returns"])
    assert_equal({}, save["args"], "anonymous ** is not sampled")
    greet = types("Widget", "greet")
    assert_equal({"other" => {"String" => 1, "Symbol" => 3}, "loud" => {"TrueClass" => 1, "FalseClass" => 3}}, greet["args"])
    assert_equal({"String" => 1, "NilClass" => 3}, greet["returns"])
    assert_equal({"String" => 1, "Integer" => 1}, greet["ivars"]["@sample"], "absence must not be recorded as nil")
    # Test methods are not sampled.
    assert_nil types("WidgetTest", "test_label")
  end

  def test_exception_unwinds_do_not_become_nil_return_samples
    assert_equal "exception_tainted_nil_omitted_v1", @o["return_sampling"]
    %w[failing indirect ensured rescued_nil].each do |name|
      sample = types("ReturnProbe", name)
      assert_equal({}, sample["returns"], name)
      assert_equal({}, sample["ivars"], name)
      assert_equal sample["calls"], sample["exception_tainted_returns"], name
    end
    assert_equal({"ReturnProbe::Value" => 1}, types("ReturnProbe", "rescued")["returns"])
    # Some VM/compiler versions report nil for non-local ensure returns.
    # Refusal is allowed; a fabricated nil observation is not.
    assert_includes [{}, {"Symbol" => 1}], types("ReturnProbe", "ensure_return")["returns"]
    failing = types("ReturnProbe", "failing")
    assert_equal 4, failing["calls"]
    assert failing["saturated"], "all-raising calls must still exhaust the sample cap"
    assert_equal({"value" => {"Symbol" => 4}}, failing["args"])
    recursive = types("ReturnProbe", "recursive")
    assert_equal({"String" => 1}, recursive["returns"])
    assert_equal 3, recursive["exception_tainted_returns"]
    assert_equal({"NilClass" => 1}, types("ReturnProbe", "normal_nil")["returns"])
    assert_equal({"String" => 1}, types("ReturnProbe", "normal_value")["returns"])
    assert_equal({"Symbol" => 1}, types("ReturnProbe", "interleaved")["returns"])
    assert_equal 1, types("ReturnProbe", "interleaved")["exception_tainted_returns"]
    assert_equal({"Symbol" => 1}, types("ReturnProbe", "concurrent")["returns"])
  end

  def test_lightweight_types_only_run_preserves_samples_and_outcomes
    _dir, data, log, status = self.class.observed_run(types_only: true)
    assert status.success?, log
    assert_match(/3 runs, \d+ assertions, 0 failures, 0 errors/, log)
    refute data.key?("generated_scripts")
    refute data.key?("defined_after_boot")
    assert_equal @o["types"].map { |t| t.slice("module", "name", "returns", "args", "ivars") },
                 data["types"].sort_by { |t| [t["module"], t["singleton"] ? 1 : 0, t["name"]] }
                   .map { |t| t.slice("module", "name", "returns", "args", "ivars") }
  end
end

# Integration: observe real-blog's own suite (skipped when absent).
class ObserveCorpusTest < Minitest::Test
  include LowrailTest

  APP = File.join(CORPUS_ROOT, "real-blog-r4")

  def test_real_blog_suite
    skip "no #{APP} (see script/corpus)" unless File.exist?(File.join(APP, "Gemfile.lock"))
    Dir.mktmpdir do |dir|
      obs = File.join(dir, "observe")
      env = CLEAN_ENV.merge("RUBYOPT" => "-I#{GEM_LIB} -rlowrail/observe", "LOWRAIL" => "0", "PARALLEL_WORKERS" => "1",
                            "LOWRAIL_OBSERVE" => obs, "LOWRAIL_OBSERVE_ROOT" => APP)
      run = -> { Open3.capture3(env, "bin/rails", "test", chdir: APP) }
      out, err, status = defined?(Bundler) ? Bundler.with_unbundled_env(&run) : run.call
      assert status.success?, err + out
      assert_match(/0 failures, 0 errors/, out)
      files = Dir[File.join(obs, "observed-*.json")]
      assert_operator files.size, :>=, 1
      # Rails test preparation may also boot a child process (asset tasks).
      # Check the process that actually ran the controller suite.
      o = files.map { |f| JSON.parse(File.read(f)) }.find do |data|
        data["types"].any? { |t| t["module"] == "ArticlesController" && t["name"] == "show" }
      end
      refute_nil o, "no controller samples in #{files.size} process files"
      assert_operator o["defined_after_boot"].size, :>, 1000
      show = o["types"].find { |t| t["module"] == "ArticlesController" && t["name"] == "show" }
      refute_nil show, o["types"].map { |t| t.values_at("module", "name") }.inspect
      assert_equal({"ArticlesController" => show["calls"]}, show["self"])
      assert(o["generated_scripts"].any? { |s| s["phase"] == "test" && s["path"].end_with?(".html.erb") })
    end
  end
end
