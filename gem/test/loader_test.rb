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

  REQUIRE_HOOKS_VERSIONS = Gem::Specification.find_all_by_name("require-hooks").map { _1.version.to_s }.uniq

  POLICY = <<~'RUBY'
    def install_loader(name)
      case name
      when "lowrail"
        require "lowrail/setup"
      when "bootsnap"
        gem "bootsnap", ENV.fetch("BS")
        require "bootsnap"
        Bootsnap.setup(cache_dir: ENV.fetch("BOOTSNAP_CACHE_DIR") { File.join(Dir.pwd, "cache") },
                       development_mode: false, load_path_cache: false,
                       compile_cache_iseq: true, compile_cache_yaml: false)
        if ENV["SELECTOR"]
          Bootsnap::CompileCache::ISeq.compiler_selector = ->(path) {
            Bootsnap::CompileCache::ISeq::FROZEN_STRING_LITERAL if path.start_with?(Dir.pwd)
          }
        end
      when "freezolite"
        gem "require-hooks", ENV.fetch("RH")
        require "freezolite"
        Freezolite.setup(patterns: ["#{Dir.pwd}/*.rb"], exclude_patterns: ["#{Dir.pwd}/outside.rb"])
      end
    end
    ENV.fetch("ORDER", "bootsnap,freezolite").split(",").each { install_loader(_1) }
  RUBY

  FROZEN_SCRIPT = <<~'RUBY'
    require "json"
    require_relative "config/policy"
    require_relative "app"
    puts JSON.generate("compute" => Calc.new.compute(1), "frozen" => Calc.new.name.frozen?,
                       "name" => Calc.new.name, "outside" => OUTSIDE, "explicit" => EXPLICIT,
                       "loaded" => defined?(Lowrail::Stats) ? Lowrail::Stats.loaded_files : [])
  RUBY

  def frozen_app(dir)
    suffix = "require_relative 'outside'\nrequire_relative 'explicit'\n"
    build_app(dir, compile: false, lowered: LOWERED_SRC + suffix)
    File.write(File.join(dir, "app.rb"), APP_SRC + suffix)
    File.write(File.join(dir, "outside.rb"), "OUTSIDE = 'outside'.frozen?\n")
    File.write(File.join(dir, "explicit.rb"), "# frozen_string_literal: false\nEXPLICIT = 'explicit'.frozen?\n")
    FileUtils.mkdir_p(File.join(dir, "config"))
    File.write(File.join(dir, "config/policy.rb"), POLICY)
    File.write(File.join(dir, "config/environment.rb"), "require_relative 'policy'\nrequire_relative '../app'\n")
    input = JSON.parse(File.read(File.join(dir, "units.json")))
    input["rails_env"] = "test"
    File.write(File.join(dir, "units.json"), JSON.generate(input))
  end

  def test_freezolite_and_bootsnap_in_every_order_with_cold_and_warm_caches
    skip "freezolite/require-hooks not installed" if REQUIRE_HOOKS_VERSIONS.empty? || Gem::Specification.find_all_by_name("freezolite").empty?
    REQUIRE_HOOKS_VERSIONS.product([nil] + BOOTSNAP_VERSIONS).each do |rh, bs|
      realpath_tmpdir do |dir|
        frozen_app(dir)
        env = { "RUBYOPT" => "-I#{GEM_LIB}", "RH" => rh, "BS" => bs,
                "RAILS_ENV" => "test", "LOWRAIL_STATS" => "" }
        loaders = bs ? %w[lowrail bootsnap freezolite] : %w[lowrail freezolite]
        loaders.permutation.each do |order|
          # Keep the app's own loader order, even when Bootsnap hides a
          # previously installed Freezolite. Lowrail must not "fix" the app
          # into behaving differently from its LOWRAIL=0 baseline.
          build_env = env.merge("ORDER" => (order - ["lowrail"]).join(","))
          _, err, status = ruby(COMPILE, File.join(dir, "units.json"), chdir: dir, setup: false, env: build_env)
          assert status.success?, err
          assert_match(/compiled 1 file/, err)
          FileUtils.rm_rf(File.join(dir, "cache-iseq"))
          run_env = env.merge("ORDER" => order.join(","))
          # Two active runs exercise a miss and a hit, then an off run proves
          # neither one put lowered code into the app's Bootsnap cache.
          %w[1 1 0].each do |mode|
            result = ruby_json(FROZEN_SCRIPT, chdir: dir, setup: false, env: run_env.merge("LOWRAIL" => mode))
            context = "require-hooks #{rh}, bootsnap #{bs}, #{order}, LOWRAIL=#{mode}"
            assert_equal [mode == "1" ? "fast" : "orig", 2], result["compute"], context
            assert_equal(bs.nil? || order.index("bootsnap") < order.index("freezolite"), result["frozen"], context)
            assert_equal false, result["outside"], context
            assert_equal false, result["explicit"], context
            assert_equal(mode == "1" ? [File.join(dir, "app.rb")] : [], result["loaded"], context)
          end
        end
      end
    end
  end

  def test_bootsnap_per_file_compiler_options
    BOOTSNAP_VERSIONS.select { Gem::Version.new(_1) >= Gem::Version.new("1.24.0") }.each do |bs|
      realpath_tmpdir do |dir|
        frozen_app(dir)
        # This case uses Bootsnap's selector, not Freezolite or global options.
        env = { "RUBYOPT" => "-I#{GEM_LIB}", "BS" => bs, "ORDER" => "bootsnap", "SELECTOR" => "1", "RAILS_ENV" => "test" }
        _, err, status = ruby(COMPILE, File.join(dir, "units.json"), chdir: dir, setup: false, env: env)
        assert status.success?, err
        assert_match(/compiled 1 file/, err)
        %w[lowrail,bootsnap bootsnap,lowrail].each do |order|
          result = ruby_json(FROZEN_SCRIPT, chdir: dir, setup: false, env: env.merge("ORDER" => order))
          assert_equal ["fast", 2], result["compute"]
          assert_equal true, result["frozen"]
          # Removing the per-file policy must reject the old lowered ISeq.
          result = ruby_json(FROZEN_SCRIPT, chdir: dir, setup: false, env: env.merge("ORDER" => order, "SELECTOR" => nil))
          assert_equal ["orig", 2], result["compute"]
          assert_equal false, result["frozen"]
        end
      end
    end
  end

  def test_cached_hijacks_do_not_inherit_bootsnap_compiler_options
    skip "require-hooks/bootsnap not installed" if REQUIRE_HOOKS_VERSIONS.empty? || BOOTSNAP_VERSIONS.empty?
    REQUIRE_HOOKS_VERSIONS.product(BOOTSNAP_VERSIONS).each do |rh, bs|
      realpath_tmpdir do |dir|
        frozen_app(dir)
        # The original ISeq cannot reveal freezing options, but the lowered
        # source introduces a string. A recipe mismatch must still decline it.
        File.write(File.join(dir, "app.rb"), "VALUE = 1\n")
        File.write(File.join(dir, ".lowrail/src/app.rb"), "VALUE = 'lowered'.frozen?\n")
        env = { "RUBYOPT" => "-I#{GEM_LIB}", "RH" => rh, "BS" => bs,
                "ORDER" => "bootsnap", "RAILS_ENV" => "test" }
        _, err, status = ruby(COMPILE, File.join(dir, "units.json"), chdir: dir, setup: false, env: env)
        assert status.success?, err
        assert_match(/compiled 1 file/, err)
        code = <<~'RUBY'
          require "json"
          require_relative "config/policy"
          gem "require-hooks", ENV.fetch("RH")
          require "require-hooks/setup"
          RequireHooks.hijack_load(patterns: [File.join(Dir.pwd, "app.rb")]) do |path, source|
            previous = RubyVM::InstructionSequence.compile_option
            RubyVM::InstructionSequence.compile_option = {frozen_string_literal: true}
            RubyVM::InstructionSequence.compile_file(path)
          ensure
            RubyVM::InstructionSequence.compile_option = previous
          end
          require "lowrail/setup"
          require_relative "app"
          puts JSON.generate(VALUE)
        RUBY
        %w[1 1 0].each do |mode|
          assert_equal 1, ruby_json(code, chdir: dir, setup: false, env: env.merge("LOWRAIL" => mode)),
                       "require-hooks #{rh}, bootsnap #{bs}, LOWRAIL=#{mode}: hijack policy must survive cold/warm caches"
        end
      end
    end
  end

  def test_source_transforms_are_not_bypassed
    skip "freezolite/require-hooks not installed" if REQUIRE_HOOKS_VERSIONS.empty? || Gem::Specification.find_all_by_name("freezolite").empty?
    realpath_tmpdir do |dir|
      frozen_app(dir)
      env = { "RUBYOPT" => "-I#{GEM_LIB}", "RH" => REQUIRE_HOOKS_VERSIONS.first, "ORDER" => "freezolite", "RAILS_ENV" => "test" }
      _, err, status = ruby(COMPILE, File.join(dir, "units.json"), chdir: dir, setup: false, env: env)
      assert status.success?, err
      transform = <<~'RUBY'
        RequireHooks.source_transform(patterns: [File.join(Dir.pwd, "app.rb")]) do |path, source|
          (source || File.read(path)).sub('"calc"', '"transformed"')
        end
      RUBY
      code = FROZEN_SCRIPT.sub('require_relative "app"', "#{transform}\nrequire_relative 'app'")
      result = ruby_json(code, chdir: dir, setup: false, env: env.merge("ORDER" => "lowrail,freezolite"))
      assert_equal ["orig", 2], result["compute"]
      assert_equal "transformed", result["name"]
      # The build must also decline source it has not analyzed, not compile
      # lowerings from untransformed text over the loader's transformed code.
      File.open(File.join(dir, "config/policy.rb"), "a") { _1.write(transform) }
      _, err, status = ruby(COMPILE, File.join(dir, "units.json"), chdir: dir, setup: false, env: env)
      assert status.success?, err
      assert_match(/app loader transformed the source/, err)
      assert_match(/compiled 0 file\(s\), 0 unit/, err)
    end
  end

  def test_coverage_disables_serving
    realpath_tmpdir do |dir|
      build_app(dir)
      code = <<~'RUBY'
        require "coverage"
        Coverage.start
        require "json"
        path = File.join(Dir.pwd, "app.rb")
        require path
        result = Calc.new.compute(1)
        puts JSON.generate("result" => result, "lines" => Coverage.result.fetch(path))
      RUBY
      result = ruby_json(code, chdir: dir)
      assert_equal ["orig", 2], result["result"]
      assert_operator result["lines"].compact.sum, :>, 0, "the VM must still instrument the original source"
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
