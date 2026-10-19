# frozen_string_literal: true

require_relative "test_helper"

# The load_iseq hook must sit in front of Bootsnap's (which does not call
# super) whichever is set up first.
class LoaderTest < Minitest::Test
  include LowrailTest

  BOOTSNAP_VERSIONS = Gem::Specification.find_all_by_name("bootsnap").map { _1.version.to_s }.uniq

  SCRIPT = <<~'RUBY'
    require "json"
    gem "bootsnap", ENV.fetch("BS")
    require "bootsnap"
    bootsnap = -> { Bootsnap.setup(cache_dir: ENV.fetch("CACHE"), development_mode: false, load_path_cache: true,
                                   compile_cache_iseq: true, compile_cache_yaml: false) }
    lowrail = -> { require "lowrail/setup" }
    ENV["ORDER"] == "lowrail_first" ? (lowrail.(); bootsnap.()) : (bootsnap.(); lowrail.())
    $LOAD_PATH.unshift Dir.pwd
    require "app"
    require "other"
    puts JSON.generate("compute" => Calc.new.compute(1), "other" => OTHER,
                       "cached" => Dir[File.join(ENV.fetch("CACHE"), "**/*")].count { File.file?(_1) })
  RUBY

  def test_composes_with_bootsnap_in_both_orders
    skip "bootsnap not installed" if BOOTSNAP_VERSIONS.empty?
    BOOTSNAP_VERSIONS.each do |bs|
      %w[bootsnap_first lowrail_first].each do |order|
        realpath_tmpdir do |dir|
          build_app(dir)
          File.write(File.join(dir, "other.rb"), "OTHER = :plain\n")
          r = ruby_json(SCRIPT, chdir: dir, setup: false,
                                env: { "RUBYOPT" => "-I#{GEM_LIB}", "BS" => bs, "ORDER" => order, "CACHE" => File.join(dir, "cache") })
          assert_equal ["fast", 2], r["compute"], "bootsnap #{bs}, #{order}: lowered file not served"
          assert_equal "plain", r["other"]
          assert_operator r["cached"], :>, 0, "bootsnap #{bs}, #{order}: other files must still go through Bootsnap"
        end
      end
    end
  end

  def test_coverage_disables_serving
    realpath_tmpdir do |dir|
      build_app(dir)
      code = 'require "coverage"; Coverage.start; require "json"; require File.join(Dir.pwd, "app"); puts JSON.generate(Calc.new.compute(1))'
      assert_equal ["orig", 2], ruby_json(code, chdir: dir)
    end
  end

  def test_setup_loads_no_default_gems
    # Under RUBYOPT we run before bundler/setup; activating the default json
    # or digest gem here would conflict with an app lockfile pinning another
    # version.
    realpath_tmpdir do |dir|
      build_app(dir)
      code = 'p Gem.loaded_specs.keys.sort, $LOADED_FEATURES.grep(%r{/(json|digest|strscan)[./]}).size'
      out, err, status = ruby("-e", code, chdir: dir, env: { "LOWRAIL_OUTCOMES" => File.join(dir, "o.json") })
      assert status.success?, err
      specs, features = out.lines.map { eval(_1) } # rubocop:disable Security/Eval
      assert_empty specs & %w[json digest strscan], "default gems activated at setup: #{specs.inspect}"
      assert_equal 0, features
    end
  end
end
