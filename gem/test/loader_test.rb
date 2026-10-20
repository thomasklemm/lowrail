# frozen_string_literal: true

require_relative "test_helper"

# Delivery must not define, hide or reorder any load_iseq method.
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
      when "require-hooks"
        gem "require-hooks", ENV.fetch("RH")
        require "require-hooks/setup"
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

  def test_load_iseq_state_matches_off_during_build_and_cold_and_warm_delivery
    skip "require-hooks/bootsnap not installed" if REQUIRE_HOOKS_VERSIONS.empty? || BOOTSNAP_VERSIONS.empty?
    state = <<~'RUBY'
      def load_state
        method = RubyVM::InstructionSequence.method(:load_iseq) if RubyVM::InstructionSequence.respond_to?(:load_iseq)
        chain = []
        while method
          chain << [method.owner.to_s, method.source_location, method.parameters]
          method = method.super_method
        end
        [chain, defined?(RequireHooks::Bootsnap), defined?(RequireHooks::LoadIseq)]
      end
    RUBY
    [nil, *REQUIRE_HOOKS_VERSIONS].product([nil, BOOTSNAP_VERSIONS.max_by { Gem::Version.new(_1) }]).each do |rh, bs|
      realpath_tmpdir do |dir|
        frozen_app(dir)
        File.write(File.join(dir, "config/policy.rb"), state + POLICY)
        File.open(File.join(dir, "config/environment.rb"), "a") do |file|
          file.puts 'File.write(ENV.fetch("STATE_OUT"), JSON.generate(load_state))'
        end
        env = { "RUBYOPT" => "-I#{GEM_LIB}", "RH" => rh, "BS" => bs, "RAILS_ENV" => "test",
                "STATE_OUT" => File.join(dir, "state.json"), "LOWRAIL_STATS" => "",
                "LOWRAIL_OUTCOMES" => File.join(dir, "outcomes.json"), "LOWRAIL_VERIFY_LOADS" => "1" }
        loaders = ["lowrail"]
        loaders << "bootsnap" if bs
        loaders << "require-hooks" if rh
        # Like the Rails corpus, this fixture uses SHA2 in both modes. Test
        # loader composition separately from Lowrail's lazy stdlib dependency.
        code = "require 'digest/sha2'\n" + FROZEN_SCRIPT.sub('"compute" =>', '"state" => load_state, "loads" => Lowrail::VerifyLoads.snapshot.fetch("stages"), "compute" =>')
        loaders.permutation.each do |order|
          run_env = env.merge("ORDER" => order.join(","))
          baseline = ruby_json(code, chdir: dir, setup: false, env: run_env.merge("LOWRAIL" => "0"))
          _, err, status = ruby(COMPILE, File.join(dir, "units.json"), chdir: dir, setup: false, env: run_env)
          assert status.success?, err
          assert_match(/compiled 1 file/, err)
          context = "require-hooks #{rh}, bootsnap #{bs}, #{order}"
          assert_equal baseline["state"], JSON.parse(File.read(env.fetch("STATE_OUT"))), "build: #{context}"
          FileUtils.rm_rf(File.join(dir, "cache-iseq"))
          %w[1 1 0].each do |mode|
            result = ruby_json(code, chdir: dir, setup: false, env: run_env.merge("LOWRAIL" => mode))
            assert_equal baseline["state"], result["state"], context
            assert_equal baseline["loads"], result["loads"], context
            assert_equal [mode == "1" ? "fast" : "orig", 2], result["compute"], context
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

  def test_order_sensitive_bundle_refuses_old_and_new_artifacts_before_installing
    realpath_tmpdir do |dir|
      build_app(dir)
      lock = File.join(dir, "Gemfile.lock")
      File.write(lock, "GEM\n  specs:\n    bundlebun (0.5.0.1.3.14-x86_64-linux-gnu)\n")
      code = <<~'RUBY'
        require "json"
        require_relative "app"
        puts JSON.generate("result" => Calc.new.compute(1), "stats" => Lowrail::Stats.snapshot,
                           "manifest" => Lowrail.manifest, "guard" => defined?(Lowrail::Guard))
      RUBY
      assert_refused = -> {
        result = ruby_json(code, chdir: dir, env: { "LOWRAIL_STATS" => "" })
        assert_equal ["orig", 2], result["result"]
        assert_nil result["manifest"]
        assert_nil result["guard"]
        assert_empty result["stats"]["loaded_files"]
        assert_empty result["stats"]["unit_hits"]
        assert_match(/bundlebun_load_order/, result["stats"]["refusal_reason"])
      }
      assert_refused.call # Existing builds must refuse too.
      _, err, status = ruby(COMPILE, File.join(dir, "units.json"), chdir: dir, setup: false)
      assert status.success?, err
      assert_match(/bundlebun_load_order/, err)
      ledger = JSON.parse(File.read(File.join(dir, ".lowrail/ledger.json")))
      assert_equal [["refused", "bundlebun_load_order"]],
                   ledger.select { _1["pass"] == "delivery" }.map { [_1["outcome"], _1["reason"]] }
      File.unlink(lock)
      assert_refused.call # A recorded refusal needs a rebuild, not lock drift.
    end
  end

  def test_explicit_compilation_never_serializes_lowered_code
    realpath_tmpdir do |dir|
      build_app(dir)
      code = <<~'RUBY'
        require "json"
        path = File.join(Dir.pwd, "app.rb")
        api = RubyVM::InstructionSequence
        original = api.compile_file(path)
        api.load_from_binary(original.to_binary).eval
        serialized = Calc.new.compute(1)
        original.eval
        evaluated = Calc.new.compute(1)
        # A display filename need not equal the absolute source identity.
        # translate must not replace this transformed compiler input by disk.
        changed = File.read(path).sub('"calc"', '"changed"')
        iseq = api.compile(changed, "display.rb", path, 1)
        api.load_from_binary(iseq.to_binary).eval
        puts JSON.generate([serialized, evaluated, Calc.new.compute(1), Calc.new.name])
      RUBY
      assert_equal [["orig", 2], ["fast", 2], ["orig", 2], "changed"], ruby_json(code, chdir: dir)
    end
  end

  def test_existing_compiler_and_translation_hooks_retain_original_behavior_in_both_orders
    realpath_tmpdir do |dir|
      build_app(dir)
      translator = <<~'RUBY'
        module AppTranslator
          def translate(iseq)
            result = defined?(super) ? super : iseq
            if iseq.absolute_path == File.join(Dir.pwd, "app.rb") && iseq.to_a[9] == :top
              raise "translator received lowered bytecode" if result.disasm.include?(":fast")
            end
            result
          end
        end
        RubyVM::InstructionSequence.singleton_class.prepend(AppTranslator)
      RUBY
      compiler = <<~'RUBY'
        module AppCompiler
          def compile_file(path, ...)
            $compiler_calls = ($compiler_calls || 0) + 1 if path == File.join(Dir.pwd, "app.rb")
            super
          end
        end
        RubyVM::InstructionSequence.singleton_class.prepend(AppCompiler)
      RUBY
      warnings = <<~'RUBY'
        Warning.singleton_class.prepend(Module.new do
          def warn(...) = super
        end)
      RUBY
      [[translator, "orig"], [compiler, "fast"], [warnings, "orig"]].each do |policy, active_result|
        %w[before after].each do |order|
          setup = 'require "lowrail/setup"'
          code = (order == "before" ? [policy, setup] : [setup, policy]).join("\n") + <<~'RUBY'

            require "json"
            require_relative "app"
            puts JSON.generate([Calc.new.compute(1), $compiler_calls || 0])
          RUBY
          %w[0 1].each do |mode|
            expected = mode == "1" ? active_result : "orig"
            assert_equal [[expected, 2], 0], ruby_json(code, chdir: dir, setup: false,
                                                    env: { "RUBYOPT" => "-I#{GEM_LIB}", "LOWRAIL" => mode })
          end
        end
      end
    end
  end

  def test_native_delivery_does_not_evaluate_during_build_or_reemit_warnings
    realpath_tmpdir do |dir|
      executed = File.join(dir, "executed")
      suffix = "\nBEGIN { File.write(#{executed.inspect}, 'yes') }\n"
      build_app(dir, compile: false, lowered: LOWERED_SRC + suffix)
      File.write(File.join(dir, "app.rb"), APP_SRC.sub("[:orig, Dep.value + x]",
        "unused_warning_variable = 1; [:orig, Dep.value + x]") + suffix)
      _, err, status = ruby(COMPILE, File.join(dir, "units.json"), setup: false)
      assert status.success?, err
      refute File.exist?(executed), "native certification must stop before app evaluation"
      code = <<~'RUBY'
        require "json"
        $VERBOSE = true
        require_relative "app"
        require_relative "app"
        puts JSON.generate(Calc.new.compute(1))
      RUBY
      %w[0 1].each do |mode|
        out, err, status = ruby("-e", code, chdir: dir, env: { "LOWRAIL" => mode })
        assert status.success?, err
        assert_equal [mode == "1" ? "fast" : "orig", 2], JSON.parse(out.lines.last)
        assert_equal 1, err.scan("unused_warning_variable").size, "source compilation warnings must occur once"
      end
      assert File.exist?(executed)
    end
  end

  def test_inner_compiler_overrides_do_not_inherit_the_outer_default_recipe
    realpath_tmpdir do |dir|
      build_app(dir, compile: false, lowered: "VALUE = 'introduced'.frozen?\n")
      File.write(File.join(dir, "app.rb"), "VALUE = 1\n")
      _, err, status = ruby(COMPILE, File.join(dir, "units.json"), setup: false)
      assert status.success?, err
      policy = <<~'RUBY'
        RubyVM::InstructionSequence.singleton_class.prepend(Module.new do
          def compile_file(...)
            previous = RubyVM::InstructionSequence.compile_option
            RubyVM::InstructionSequence.compile_option = {frozen_string_literal: true}
            super
          ensure
            RubyVM::InstructionSequence.compile_option = previous
          end
        end)
      RUBY
      %w[before after].each do |order|
        setup = 'require "lowrail/setup"'
        code = (order == "before" ? [policy, setup] : [setup, policy]).join("\n") + <<~'RUBY'

          require "json"
          RubyVM::InstructionSequence.compile_file(File.join(Dir.pwd, "app.rb")).eval
          puts JSON.generate(VALUE)
        RUBY
        %w[0 1].each do |mode|
          assert_equal 1, ruby_json(code, chdir: dir, setup: false,
                                   env: { "RUBYOPT" => "-I#{GEM_LIB}", "LOWRAIL" => mode })
        end
      end
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
