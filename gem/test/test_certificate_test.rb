# frozen_string_literal: true

require_relative "test_helper"

class TestCertificateTest < Minitest::Test
  include LowrailTest

  def test_cross_environment_opt_ins_and_unknown_workers_refuse
    rows = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "lowrail"
      require "lowrail/manifest"
      data = {"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
        "compile_option" => "", "files" => {}, "units" => [{"id" => 0, "pass" => "sealed/link_to", "facts" => []}]}
      production = data.merge("tier" => "sealed-v1", "rails_env" => "production")
      verification = data.merge("tier" => "sealed-test-v1", "rails_env" => "test",
        "verification_test" => {"version" => 1, "mode" => "verification-only"})
      ENV["LOWRAIL_SEALED"], ENV["LOWRAIL_VERIFY_TEST"] = "1", "1"
      puts JSON.generate([[production, "test", "1"], [verification, "production", "1"],
        [verification, "test", nil], [verification, "test", "2"],
        [verification, "test", "1"], [production, "production", "1"]].map do |artifact, env, workers|
        ENV["RAILS_ENV"], ENV["PARALLEL_WORKERS"] = env, workers
        Lowrail::Manifest.new(artifact, "/tmp").compatible?
      end)
    RUBY
    assert_equal [false, false, false, false, true, true], rows
  end

  def test_missing_real_initialization_never_authorizes_a_fact_free_unit
    result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "tmpdir"
      require "lowrail"
      ENV.update("RAILS_ENV" => "test", "PARALLEL_WORKERS" => "1", "LOWRAIL" => "1",
        "LOWRAIL_SEALED" => "1", "LOWRAIL_VERIFY_TEST" => "1")
      data = {"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
        "certification_jit" => Lowrail.jit_mode, "compile_option" => "", "files" => {},
        "tier" => "sealed-test-v1", "rails_env" => "test",
        "verification_test" => {"version" => 1, "mode" => "verification-only"},
        "units" => [{"id" => 0, "pass" => "active_record/instantiate", "facts" => [],
          "kind" => "runtime", "ar_instantiate" => {"model" => "NotLoaded"}}]}
      Dir.mktmpdir do |root|
        Dir.mkdir("#{root}/.lowrail")
        File.write("#{root}/.lowrail/manifest.json", JSON.generate(data))
        installed = Lowrail.setup(root: root)
        before = [Lowrail::TestCertificate.status, Lowrail.check(0), Lowrail::Stats.unit_hits]
        Lowrail::TestCertificate.test_initialized!
        puts JSON.generate([installed, before, Lowrail.check(0), Lowrail::TestCertificate.evidence])
      end
    RUBY
    assert_equal true, result[0]
    assert_equal ["pending", false, {}], result[1]
    assert_equal false, result[2]
    assert_equal "refused", result[3].fetch("state")
    refute_empty result[3].fetch("unit_refusals").fetch("0")
  end

  def test_source_set_includes_additions_removals_boot_and_test_initialization
    result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "tmpdir"
      require "fileutils"
      require "lowrail"
      require "lowrail/manifest"
      require "lowrail/test_certificate"
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(["#{root}/config", "#{root}/test"])
        File.write("#{root}/config/boot.rb", "boot")
        File.write("#{root}/test/test_helper.rb", "workers")
        original = Lowrail::TestCertificate.sources(root)
        File.write("#{root}/config/new.rb", "added")
        added = Lowrail::TestCertificate.sources(root)
        File.unlink("#{root}/test/test_helper.rb")
        removed = Lowrail::TestCertificate.sources(root)
        puts JSON.generate([original.keys, original != added, added != removed])
      end
    RUBY
    assert_equal ["config/boot.rb", "test/test_helper.rb"], result[0]
    assert_equal [true, true], result.drop(1)
  end
end
