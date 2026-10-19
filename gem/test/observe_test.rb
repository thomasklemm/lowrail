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
        end

        def test_relation_delegation
          Widget.create!(name: "b", password: "secret")
          assert_equal "b", Widget.named.cheapest.name
        end
      end
    RUBY
  }.freeze

  def self.observed_run(samples: 4)
    @runs ||= {}
    @runs[samples] ||= begin
      dir = File.realpath(Dir.mktmpdir("lowrail-obs"))
      LowrailTest.write_rails_app(dir, SUITE)
      obs = File.join(dir, ".lowrail", "observe")
      env = CLEAN_ENV.merge("RUBYOPT" => "-I#{GEM_LIB} -rlowrail/observe", "LOWRAIL" => "0",
                            "LOWRAIL_OBSERVE" => obs, "LOWRAIL_OBSERVE_SAMPLES" => samples.to_s,
                            "LOWRAIL_OBSERVE_METHODS" => "ActiveRecord::Base#save!,Nope#missing")
      out, err, status = Open3.capture3(env, RUBY, "-Itest", "test/models/widget_test.rb", chdir: dir)
      files = Dir[File.join(obs, "observed-*.json")]
      data = files.size == 1 ? JSON.parse(File.read(files.first)) : nil
      [dir, data, out + err, status]
    end
  end

  def setup
    skip "Rails, sqlite3 or bcrypt not installed" unless LowrailTest.rails_installed?
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
    assert_match(/2 runs, \d+ assertions, 0 failures, 0 errors/, @log)
    assert_match(/cannot hook Nope#missing/, @log)
  end

  def test_definitions_after_boot
    # Without materialize, attribute methods appear during the run.
    m = defined("Widget::GeneratedAttributeMethods", "name")
    refute_nil m
    assert m["script"], "linked to its generated script"
    assert(@o["generated_scripts"].any? { |s| s["sha256"] == m["script"] && s["phase"] == "test" })
    assert File.exist?(File.join(@dir, ".lowrail", "generated", "#{m["script"]}.rb"))
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
    assert_equal({"TrueClass" => 1}, save["returns"])
    assert_equal({}, save["args"], "anonymous ** is not sampled")
    greet = types("Widget", "greet")
    assert_equal({"other" => {"String" => 1, "Symbol" => 1}, "loud" => {"TrueClass" => 1, "FalseClass" => 1}}, greet["args"])
    assert_equal({"String" => 1, "NilClass" => 1}, greet["returns"])
    # Test methods are not sampled.
    assert_nil types("WidgetTest", "test_label")
  end
end

# Integration: observe real-blog's own suite (skipped when absent).
class ObserveCorpusTest < Minitest::Test
  include LowrailTest

  APP = File.expand_path("../../.corpus/real-blog-r4", __dir__)

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
      assert_equal 1, files.size
      o = JSON.parse(File.read(files.first))
      assert_operator o["defined_after_boot"].size, :>, 1000
      show = o["types"].find { |t| t["module"] == "ArticlesController" && t["name"] == "show" }
      refute_nil show, o["types"].map { |t| t.values_at("module", "name") }.inspect
      assert_equal({"ArticlesController" => show["calls"]}, show["self"])
      assert(o["generated_scripts"].any? { |s| s["phase"] == "test" && s["path"].end_with?(".html.erb") })
    end
  end
end
